#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./source.properties
if [ ! -e upstream ]; then
  git clone --no-checkout --no-tags --filter=blob:none "$REPO" upstream
fi
test "$(git -C upstream remote get-url origin)" = "$REPO"
git -C upstream checkout --detach "$COMMIT"
test "$(git -C upstream rev-parse HEAD)" = "$COMMIT"
git -C upstream diff --quiet HEAD -- pom.xml src
test -z "$(git -C upstream ls-files --others -- src)"
