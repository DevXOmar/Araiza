#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source app/source.properties

sudo apt-get update
sudo apt-get install -y openjdk-21-jdk-headless git maven curl ca-certificates docker.io
bash app/fetch.sh
mvn -B -ntp -f app/upstream/pom.xml clean test package

sudo systemctl enable --now docker

tomcat_dir=/opt/araiza-s7-tomcat
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
if ! id araiza-s7 >/dev/null 2>&1; then
    sudo useradd --system --user-group --no-create-home --shell /usr/sbin/nologin araiza-s7
fi
if systemctl is-active --quiet araiza-s7-tomcat; then
    sudo systemctl stop araiza-s7-tomcat
fi
sudo install -d -m 0755 "$tomcat_dir"
sudo tar --extract --gzip --file "$work_dir/$archive" --strip-components=1 \
  --exclude="apache-tomcat-$tomcat_version/webapps/*" -C "$tomcat_dir"
sudo install -d -m 0755 "$tomcat_dir/webapps"
sudo rm -rf "$tomcat_dir/webapps/ROOT" "$tomcat_dir/webapps/lab"
sudo install -m 0644 "app/upstream/target/$WAR" "$tomcat_dir/webapps/ROOT.war"
sudo chown -R araiza-s7:araiza-s7 "$tomcat_dir"

sudo tee /etc/systemd/system/araiza-s7-tomcat.service >/dev/null <<UNIT
[Unit]
Description=Araiza S7 Tomcat 9
After=network.target

[Service]
Type=simple
User=araiza-s7
Group=araiza-s7
Environment=JAVA_HOME=/usr/lib/jvm/java-21-openjdk-$(dpkg --print-architecture)
Environment="JAVA_OPTS=-Xms32m -Xmx192m"
ExecStart=$tomcat_dir/bin/catalina.sh run
Restart=on-failure
RestartSec=3s
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now araiza-s7-tomcat
curl -fsS --retry 20 --retry-all-errors --retry-delay 2 http://127.0.0.1:8080/ >/dev/null
printf '%s\n' 'Tomcat served the root context on port 8080.'
