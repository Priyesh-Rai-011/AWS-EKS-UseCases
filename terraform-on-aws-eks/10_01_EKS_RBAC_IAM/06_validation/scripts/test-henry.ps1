# Henry — break-glass (AmazonEKSClusterAdminPolicy)
# NEVER use for day-to-day work.
# Expected: everything ALLOWED — full cluster-admin

$env:AWS_PROFILE = "henry"
$CLUSTER = "eks-rbac-dev"
$REGION  = "ap-south-1"

$arn = aws sts get-caller-identity --query Arn --output text
Write-Host "=== Identity: $arn ===" -ForegroundColor Cyan
Write-Host "WARNING: cluster-admin access. Use only in emergencies." -ForegroundColor Yellow

aws eks update-kubeconfig --name $CLUSTER --region $REGION | Out-Null

Write-Host "`n=== Henry access matrix (all ALLOWED - cluster-admin) ===" -ForegroundColor Cyan
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

Run-Test "get pods (backend-prod)"      ALLOWED get,pods,          -n,backend-prod
Run-Test "get secrets (backend-prod)"   ALLOWED get,secrets,       -n,backend-prod
Run-Test "exec into pod (backend-prod)" ALLOWED create,pods/exec,  -n,backend-prod
Run-Test "delete pod (backend-prod)"    ALLOWED delete,pods,       -n,backend-prod
Run-Test "get nodes (cluster-wide)"     ALLOWED get,nodes
Run-Test "list namespaces"              ALLOWED list,namespaces
Run-Test "create namespace"             ALLOWED create,namespaces
Run-Test "delete namespace"             ALLOWED delete,namespaces

Write-Host "`n=== Result: $($script:PASS) passed, $($script:FAIL) failed ===" -ForegroundColor Cyan
Write-Host "`nREMINDER: Revoke these credentials immediately after use." -ForegroundColor Yellow
