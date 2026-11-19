$ErrorActionPreference = 'Stop'
$source = Get-Content -Raw (Join-Path $PSScriptRoot 'source.properties') | ConvertFrom-StringData
$destination = Join-Path $PSScriptRoot 'upstream'

if (-not (Test-Path $destination)) {
    git clone --no-checkout --no-tags --filter=blob:none $source.REPO $destination
    if ($LASTEXITCODE -ne 0) { throw 'Upstream clone failed' }
}
$remote = git -C $destination remote get-url origin
if ($LASTEXITCODE -ne 0 -or $remote -ne $source.REPO) {
    throw "Unexpected checkout at $destination. Move it aside and retry."
}
git -C $destination checkout --detach $source.COMMIT
if ($LASTEXITCODE -ne 0) { throw 'Pinned checkout failed' }
$head = git -C $destination rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head -ne $source.COMMIT) { throw 'Incorrect upstream commit' }
git -C $destination diff --quiet HEAD -- pom.xml src
if ($LASTEXITCODE -ne 0) { throw 'Tracked Maven inputs differ from the pinned revision' }
$unexpected = git -C $destination ls-files --others -- src
if ($LASTEXITCODE -ne 0 -or $unexpected) { throw 'Untracked files under upstream/src' }
