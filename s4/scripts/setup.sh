#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" != --env-only ]; then bash app/fetch.sh; fi
if [ "${1:-}" = --fetch-only ]; then exit 0; fi
if [ ! -e .env ]; then
  umask 077
  while IFS= read -r line; do
    case "$line" in
      *=) printf '%s%s\n' "$line" "$(openssl rand -hex 24)" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < .env.example > .env
fi
if [ "${1:-}" = --env-only ]; then exit 0; fi
docker build --target app -t araiza-s4:v1 .
