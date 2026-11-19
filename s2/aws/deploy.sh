#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source app/source.properties

sudo apt-get update
sudo apt-get install -y openjdk-21-jdk-headless git maven curl ca-certificates postgresql openssl
bash app/fetch.sh
mvn -B -ntp -f app/upstream/pom.xml clean test package

sudo systemctl enable --now postgresql
if ! sudo test -s /etc/araiza-s2-db.env; then
    DB_PASSWORD="$(openssl rand -hex 24)"
    umask 077
    printf '%s\n' \
      'DB_URL=jdbc:postgresql://127.0.0.1:5432/hms?connectTimeout=3&socketTimeout=5' \
      'DB_USER=hms_app' "DB_PASSWORD=$DB_PASSWORD" | sudo tee /etc/araiza-s2-db.env >/dev/null
    sudo chmod 0600 /etc/araiza-s2-db.env
    unset DB_PASSWORD
fi
# The env file contains only the assigned values above. Read it in a root subprocess.
sudo bash -e <<'ROOT'
set -a
source /etc/araiza-s2-db.env
set +a
sudo --preserve-env=DB_PASSWORD -u postgres psql -v ON_ERROR_STOP=1 <<'SQL'
\getenv db_pass DB_PASSWORD
SELECT 'CREATE ROLE hms_app LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hms_app') \gexec
ALTER ROLE hms_app PASSWORD :'db_pass';
SELECT 'CREATE DATABASE hms'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'hms') \gexec
\connect hms
GRANT CONNECT ON DATABASE hms TO hms_app;
GRANT USAGE, CREATE ON SCHEMA public TO hms_app;
SET ROLE hms_app;
CREATE TABLE IF NOT EXISTS appointments (
    reference VARCHAR(60) PRIMARY KEY,
    department VARCHAR(30) NOT NULL
);
SQL
ROOT

mvn -B -ntp -f companion/pom.xml clean verify

tomcat_dir=/opt/araiza-s2-tomcat
tomcat_version=9.0.124
archive=apache-tomcat-$tomcat_version.tar.gz
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
curl -fsS --retry 3 -o "$work_dir/$archive" \
  "https://archive.apache.org/dist/tomcat/tomcat-9/v$tomcat_version/bin/$archive"
(
  cd "$work_dir"
  printf '%s  %s\n' '925e4fefe25b2ecccd032acd0b4cb1b506455037ed0f8b0e51824bed839c5e92bf5e58982b990d2fdcbc790bcda1a533db7faffb325f8a7baee939fc8ae871c1' "$archive" | sha512sum --check -
)
if ! id araiza-s2 >/dev/null 2>&1; then
    sudo useradd --system --user-group --no-create-home --shell /usr/sbin/nologin araiza-s2
fi
if systemctl is-active --quiet araiza-s2-tomcat; then
    sudo systemctl stop araiza-s2-tomcat
fi
sudo install -d -m 0755 "$tomcat_dir"
sudo tar --extract --gzip --file "$work_dir/$archive" --strip-components=1 \
  --exclude="apache-tomcat-$tomcat_version/webapps/*" -C "$tomcat_dir"
sudo install -d -m 0755 "$tomcat_dir/webapps"
sudo rm -rf "$tomcat_dir/webapps/ROOT" "$tomcat_dir/webapps/lab"
sudo install -m 0644 "app/upstream/target/$WAR" "$tomcat_dir/webapps/ROOT.war"
sudo install -m 0644 companion/target/lab.war "$tomcat_dir/webapps/lab.war"
sudo chown -R araiza-s2:araiza-s2 "$tomcat_dir"

sudo tee /etc/systemd/system/araiza-s2-tomcat.service >/dev/null <<UNIT
[Unit]
Description=Araiza S2 Tomcat 9
After=network.target postgresql.service

[Service]
Type=simple
User=araiza-s2
Group=araiza-s2
Environment=JAVA_HOME=/usr/lib/jvm/java-21-openjdk-$(dpkg --print-architecture)
Environment="JAVA_OPTS=-Xms32m -Xmx192m"
EnvironmentFile=/etc/araiza-s2-db.env
ExecStart=$tomcat_dir/bin/catalina.sh run
Restart=on-failure
RestartSec=3s
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now araiza-s2-tomcat
curl -fsS --retry 20 --retry-all-errors --retry-delay 2 http://127.0.0.1:8080/ >/dev/null
printf '%s\n' 'Tomcat served the root context on port 8080.'

curl -fsS http://127.0.0.1:8080/lab/health
