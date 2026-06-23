# Grace — security-auditor (cluster-wide)
# Expected: RBAC bindings YES, secrets YES (read only), logs YES, exec NO, write NO

$env:AWS_PROFILE = "grace"
$CLUSTER = "eks-rbac-dev"
$REGION  = "ap-south-1"

$arn = aws sts get-caller-identity --query Arn --output text
Write-Host "=== Identity: $arn ===" -ForegroundColor Cyan

aws eks update-kubeconfig --name $CLUSTER --region $REGION | Out-Null

Write-Host "`n=== Grace access matrix ===" -ForegroundColor Cyan
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

Run-Test "get clusterrolebindings"         ALLOWED get,clusterrolebindings
Run-Test "get rolebindings (backend-prod)" ALLOWED get,rolebindings,    -n,backend-prod
Run-Test "get serviceaccounts (backend)"   ALLOWED get,serviceaccounts, -n,backend-prod
Run-Test "get secrets (backend-prod)"      ALLOWED get,secrets,         -n,backend-prod
Run-Test "get secrets (frontend-prod)"     ALLOWED get,secrets,         -n,frontend-prod
Run-Test "view logs (backend-prod)"        ALLOWED get,pods/log,        -n,backend-prod
Run-Test "get networkpolicies"             ALLOWED get,networkpolicies, -n,backend-prod
Run-Test "exec into pod"                   DENIED  create,pods/exec,    -n,backend-prod
Run-Test "delete pod"                      DENIED  delete,pods,         -n,backend-prod
Run-Test "create deployment"               DENIED  create,deployments,  -n,backend-prod

Write-Host "`n=== Result: $($script:PASS) passed, $($script:FAIL) failed ===" -ForegroundColor Cyan
