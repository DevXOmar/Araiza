#!/usr/bin/env bash
set -euo pipefail
source_file="${1:-$(dirname "$0")/index.html}"
test -f "$source_file"
sudo apt-get update
sudo apt-get install -y apache2 curl
sudo install -m 0644 "$source_file" /var/www/html/index.html
sudo systemctl enable --now apache2
curl -fsS http://127.0.0.1/ | grep -F 'Blood Bank Lab Status'
