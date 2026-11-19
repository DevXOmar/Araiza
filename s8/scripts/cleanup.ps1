param([switch]$Kubernetes, [string]$Context = 'minikube')
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    if (Test-Path .env) {
        docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring down
        if ($LASTEXITCODE -ne 0) { throw 'Compose cleanup failed' }
    }
    if ($Kubernetes) {
        kubectl --context $Context delete namespace araiza-s8 --ignore-not-found
        if ($LASTEXITCODE -ne 0) { throw 'Kubernetes cleanup failed' }
    }
} finally { Pop-Location }
