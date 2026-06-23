# Dave — backend-dev (namespace: backend-prod only)
# Expected: logs YES, rollout YES, exec NO, delete NO, secrets NO, frontend DENIED

$env:AWS_PROFILE = "dave"
$CLUSTER = "eks-rbac-dev"
$REGION  = "ap-south-1"

$arn = aws sts get-caller-identity --query Arn --output text
Write-Host "=== Identity: $arn ===" -ForegroundColor Cyan

aws eks update-kubeconfig --name $CLUSTER --region $REGION | Out-Null

Write-Host "`n=== Dave access matrix ===" -ForegroundColor Cyan
$script:PASS = 0
$script:FAIL = 0

function Run-Test {
    param([string]$Label, [string]$Expected, [string[]]$KubectlArgs)
    $output = kubectl auth can-i @KubectlArgs 2>$null
    $result = if ($output -match "^yes") { "ALLOWED" } else { "DENIED" }
    if ($result -eq $Expected) {
        Write-Host "  PASS  [$result] $Label" -ForegroundColor Green
        $script:PASS++
    } else {
        Write-Host "  FAIL  [$result] $Label (expected $Expected)" -ForegroundColor Red
        $script:FAIL++
    }
}

Run-Test "get pods (backend-prod)"          ALLOWED get,pods,           -n,backend-prod
Run-Test "view logs (backend-prod)"         ALLOWED get,pods/log,       -n,backend-prod
Run-Test "rollout (patch deployment)"       ALLOWED patch,deployments,  -n,backend-prod
Run-Test "exec into pod (backend-prod)"     DENIED  create,pods/exec,   -n,backend-prod
Run-Test "create deployment (backend-prod)" DENIED  create,deployments, -n,backend-prod
Run-Test "delete pod (backend-prod)"        DENIED  delete,pods,        -n,backend-prod
Run-Test "get secrets (backend-prod)"       DENIED  get,secrets,        -n,backend-prod
Run-Test "get pods (frontend-prod)"         DENIED  get,pods,           -n,frontend-prod
Run-Test "view logs (frontend-prod)"        DENIED  get,pods/log,       -n,frontend-prod
Run-Test "get nodes"                        DENIED  get,nodes

Write-Host "`n=== Result: $($script:PASS) passed, $($script:FAIL) failed ===" -ForegroundColor Cyan
