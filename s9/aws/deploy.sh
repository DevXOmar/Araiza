#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
sudo apt-get update
sudo apt-get install -y git docker.io curl
sudo systemctl enable --now docker
bash app/fetch.sh
sudo docker build --target app -t araiza-s9:ec2 .
if sudo docker container inspect araiza-s9-ec2 >/dev/null 2>&1; then
    sudo docker rm -f araiza-s9-ec2
fi
sudo docker run -d --name araiza-s9-ec2 --restart unless-stopped -p 8090:8080 araiza-s9:ec2
curl -fsS --retry 20 --retry-all-errors --retry-delay 2 http://127.0.0.1:8090/ >/dev/null
sudo docker port araiza-s9-ec2
