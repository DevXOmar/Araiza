#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 1 ]; then
  printf '%s\n' 'Usage: bash aws/deploy.sh DOCKERHUB_USER/araiza-s1:v1' >&2
  exit 2
fi
image="$1"
sudo apt-get update
sudo apt-get install -y git docker.io curl openjdk-21-jdk-headless maven
sudo systemctl enable --now docker
bash app/fetch.sh
source app/source.properties
mvn -B -ntp -f app/upstream/pom.xml clean test package
test -s "app/upstream/target/$WAR"
sudo docker pull "$image"
if sudo docker container inspect araiza-s1-ec2 >/dev/null 2>&1; then
    sudo docker rm -f araiza-s1-ec2
fi
sudo docker run -d --name araiza-s1-ec2 --restart unless-stopped -p 80:8080 "$image"
curl -fsS --retry 20 --retry-all-errors --retry-delay 2 http://127.0.0.1/ >/dev/null
sudo docker port araiza-s1-ec2
