param([string]$Profile = 'minikube')
$ErrorActionPreference = 'Stop'
$deployment = 'araiza-s4'
$kubeArgs = @('--context', $Profile, '-n', $deployment)
function Invoke-Kube {
    kubectl @kubeArgs @args
    if ($LASTEXITCODE -ne 0) { throw "kubectl failed: $args" }
}
function Invoke-Minikube {
    minikube -p $Profile @args
    if ($LASTEXITCODE -ne 0) { throw "minikube failed: $args" }
}
function Confirm-Response {
    param([string]$Revision)
    $listener = New-Object Net.Sockets.TcpListener ([Net.IPAddress]::Loopback), 0
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    $forward = Start-Process kubectl -ArgumentList ($kubeArgs + @(
        'port-forward', "service/$deployment", "${port}:8080"
    )) -NoNewWindow -PassThru
    try {
        $ready = $false
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            try {
                $actual = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Uri "http://127.0.0.1:$port/revision/index.txt"
                if ($actual.Content.Trim() -eq $Revision) { $ready = $true; break }
            } catch {
                if ($forward.HasExited) { throw }
            }
            Start-Sleep -Seconds 1
        }
        if (-not $ready) { throw "Image revision $Revision not served" }
        $pageResponse = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Uri "http://127.0.0.1:$port/"
        if ($pageResponse.Content -notmatch [regex]::Escape('Online Shopping Management System')) { throw 'Unexpected application page' }
        $detail = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Uri "http://127.0.0.1:$port/products.jsp"
        if ($detail.StatusCode -ne 200 -or -not $detail.Content) { throw 'Application detail page failed' }
        Write-Host "$deployment served both application pages with image revision $Revision."
    } finally {
        if (-not $forward.HasExited) { Stop-Process -Id $forward.Id }
    }
}

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    minikube -p $Profile status
    if ($LASTEXITCODE -ne 0) { Invoke-Minikube start --driver=docker }
    Invoke-Minikube image load "araiza-s4:v1"
    Invoke-Kube apply -f k8s/namespace.yaml
    Invoke-Kube apply -f k8s/deployment.yaml -f k8s/service.yaml
    Invoke-Kube rollout status "deployment/$deployment" --timeout=240s
    $initial = (Invoke-Kube get deployment $deployment -o json | ConvertFrom-Json).status.readyReplicas
    if ($initial -ne 3) { throw "Unexpected initial replica count $initial" }
    $slices = (Invoke-Kube get endpointslices -l "kubernetes.io/service-name=$deployment" -o json | ConvertFrom-Json)
    if (-not ($slices.items.endpoints | Where-Object { $_.conditions.ready -eq $true })) { throw 'Service has no Ready endpoints' }
    Confirm-Response v1

    Invoke-Kube scale "deployment/$deployment" --replicas=5
    Invoke-Kube rollout status "deployment/$deployment" --timeout=240s
    $pods = (Invoke-Kube get pods -l "app=$deployment" -o json | ConvertFrom-Json).items
    if ($pods.Count -ne 5) { throw 'Unexpected scaled replica count' }
    $oldPod = $pods[0].metadata.name
    Invoke-Kube delete pod $oldPod --timeout=90s
    Invoke-Kube rollout status "deployment/$deployment" --timeout=240s
    $current = (Invoke-Kube get pods -l "app=$deployment" -o json | ConvertFrom-Json).items
    if ($current.Count -ne 5 -or $current.metadata.name -contains $oldPod) { throw 'Pod replacement was not observed' }
    Invoke-Kube get 'deployment,pods,svc' -o wide

    docker build --target app --build-arg LAB_REVISION=v2 -t "araiza-s4:v2" .
    if ($LASTEXITCODE -ne 0) { throw 'V2 build failed' }
    Invoke-Minikube image load "araiza-s4:v2"
    Invoke-Kube set image "deployment/$deployment" "web=araiza-s4:v2"
    Invoke-Kube rollout status "deployment/$deployment" --timeout=240s
    Confirm-Response v2
    Invoke-Kube rollout undo "deployment/$deployment"
    Invoke-Kube rollout status "deployment/$deployment" --timeout=240s
    Confirm-Response v1
} finally { Pop-Location }
