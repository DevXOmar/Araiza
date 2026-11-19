#!/usr/bin/env bash
set -euo pipefail
# Paste at EC2 launch in Advanced details > User data.
apt-get update
apt-get install -y git
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
git clone --depth 1 https://github.com/DevXOmar/Araiza.git "$work_dir/Araiza"
bash "$work_dir/Araiza/s8/aws/deploy-static.sh"
