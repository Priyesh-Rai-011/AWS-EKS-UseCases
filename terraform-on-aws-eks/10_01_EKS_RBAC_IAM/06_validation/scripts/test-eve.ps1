# Eve — frontend-dev (readonly in backend-prod)
# Angular on S3 — no frontend-prod k8s workloads.
# Eve can only VIEW backend pods/logs to check API health.
# Expected: read + logs in backend-prod, exec NO, secrets NO, write NO

$env:AWS_PROFILE = "eve"
$CLUSTER = "eks-rbac-dev"
$REGION  = "ap-south-1"

$arn = aws sts get-caller-identity --query Arn --output text
Write-Host "=== Identity: $arn ===" -ForegroundColor Cyan

aws eks update-kubeconfig --name $CLUSTER --region $REGION | Out-Null

Write-Host "`n=== Eve access matrix ===" -ForegroundColor Cyan
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
Run-Test "get deployments (backend-prod)"   ALLOWED get,deployments,    -n,backend-prod
Run-Test "exec into pod (backend-prod)"     DENIED  create,pods/exec,   -n,backend-prod
Run-Test "create deployment (backend-prod)" DENIED  create,deployments, -n,backend-prod
Run-Test "patch deployment (backend-prod)"  DENIED  patch,deployments,  -n,backend-prod
Run-Test "get secrets (backend-prod)"       DENIED  get,secrets,        -n,backend-prod
Run-Test "get nodes (cluster-wide)"         DENIED  get,nodes
Run-Test "list namespaces"                  DENIED  list,namespaces

Write-Host "`n=== Result: $($script:PASS) passed, $($script:FAIL) failed ===" -ForegroundColor Cyan
