param([switch]$FetchOnly, [switch]$EnvOnly)
$ErrorActionPreference = 'Stop'
$setRoot = Split-Path -Parent $PSScriptRoot
Push-Location $setRoot
try {
    if (-not $EnvOnly) { & ./app/fetch.ps1 }
    if ($FetchOnly) { return }
    if (-not (Test-Path .env)) {
        $random = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        try {
            $lines = Get-Content .env.example
            $lines = foreach ($line in $lines) {
                if ($line -match '^([A-Z_]+)=$') {
                    $key = $Matches[1]
                    $bytes = New-Object byte[] 24
                    $random.GetBytes($bytes)
                    $key + '=' + [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
                } else { $line }
            }
            $lines | Set-Content -Encoding Ascii .env
        } finally { $random.Dispose() }
    }
    if ($EnvOnly) { return }
    docker build --target app -t araiza-s9:v1 .
    if ($LASTEXITCODE -ne 0) { throw 'Application image build failed' }
} finally { Pop-Location }
