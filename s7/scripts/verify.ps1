param([switch]$RecreateDatabase, [switch]$Kubernetes, [string]$Profile = 'minikube')
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)

$composeArgs = @('-f', 'compose.yaml', '-f', 'nagios/compose.yaml', '--profile', 'monitoring')
function Invoke-LabCompose {
    docker compose @composeArgs @args
    if ($LASTEXITCODE -ne 0) { throw "Docker Compose failed: $args" }
}
function Confirm-Text {
    param([string]$Path, [string]$Text)
    for ($attempt = 0; $attempt -lt 18; $attempt++) {
        try {
            $result = Invoke-WebRequest -UseBasicParsing -TimeoutSec 6 -Uri "$base$Path"
            $body = $result.Content
            if ($body -is [byte[]]) { $body = [Text.Encoding]::UTF8.GetString($body) }
            if ($body.Contains($Text)) { return }
        } catch {
            if ($attempt -eq 17) { throw }
        }
        Start-Sleep -Seconds 2
    }
    throw "Expected text was missing from $Path"
}

try {
    $resolved = Get-Content -Raw .env | ConvertFrom-StringData
    $port = if ($env:WEB_PORT) { $env:WEB_PORT } else { $resolved.WEB_PORT }
    $base = "http://127.0.0.1:$port"
    Invoke-LabCompose config --quiet
    Invoke-LabCompose up -d --build --wait --wait-timeout 180
    Invoke-LabCompose ps

    Confirm-Text '/health' '"postgres":"ok"'
    Confirm-Text '/health' '"redis":"ok"'
    $marker = "Fixture-$([Guid]::NewGuid().ToString('N'))"
    Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$base/fixtures" -Body @{name = $marker} | Out-Null
    $path = '/fixtures'
    $before = Invoke-RestMethod -Uri "$base$path"
    $after = Invoke-RestMethod -Uri "$base$path"
    if ($after.visits -le $before.visits) { throw 'Redis visit counter did not increase' }

    Confirm-Text $path $marker
    if ($RecreateDatabase) {
        Invoke-LabCompose stop db
        Invoke-LabCompose rm -f db
        Invoke-LabCompose up -d --wait --wait-timeout 150 db
        Confirm-Text $path $marker

        Write-Host 'The same record survived database container recreation.'
    }
    Invoke-LabCompose exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
    Write-Host 'Compose, application response and Nagios configuration verified.'
    if ($Kubernetes) { & ./k8s/verify.ps1 -Profile $Profile }
} finally { Pop-Location }
