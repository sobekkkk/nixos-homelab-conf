[CmdletBinding()]
param(
    [string]$Target = "192.168.1.69",
    [string]$EvidenceDirectory = (Join-Path $env:USERPROFILE "Documents\HomelabSecurityEvidence")
)

$allowedTarget = "192.168.1.69"
if ($Target -ne $allowedTarget) {
    throw "Target '$Target' is not authorised by security/scope.yml."
}

$approvedPorts = @(22, 443, 9443, 8443, 8444)
$nmap = Get-Command nmap -ErrorAction SilentlyContinue
if (-not $nmap) {
    $nmapCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Nmap\\nmap.exe"),
        (Join-Path $env:ProgramFiles "Nmap\\nmap.exe")
    )
    $nmapPath = $nmapCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($nmapPath) {
        $nmap = Get-Command $nmapPath
    }
}
if (-not $nmap) {
    throw "Nmap is required on Windows before running this baseline. Install it from its official distribution, then retry."
}

$timestamp = Get-Date -Format "yyyyMMddTHHmmss"
$runDirectory = Join-Path $EvidenceDirectory "baseline-$timestamp"
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null

@{
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    source = $env:COMPUTERNAME
    target = $Target
    command = "nmap -Pn -n -sV --version-light --reason -p $($approvedPorts -join ', ') --open"
    nmap_version = (& $nmap.Source --version | Select-Object -First 1)
} | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $runDirectory "metadata.json")

# Service and TLS/SSH capability discovery against the single authorised host.
& $nmap.Source -Pn -n -sV --version-light --reason --open `
    -p ($approvedPorts -join ",") `
    --script "banner,ssh2-enum-algos,ssl-cert,ssl-enum-ciphers" `
    -oA (Join-Path $runDirectory "nmap") $Target

if ($LASTEXITCODE -ne 0) {
    throw "Nmap exited with code $LASTEXITCODE. Evidence is retained in $runDirectory."
}

Write-Host "Baseline complete. Review and redact evidence before sharing: $runDirectory"
