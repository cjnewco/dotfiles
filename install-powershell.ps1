# Installs the crocharisma prompt into the PowerShell profile and signs it for AllSigned machines.
# Re-run after pulling changes to crocharisma.ps1:
#   powershell -ExecutionPolicy Bypass -File ./install-powershell.ps1
# The first run adds a self-signed cert to your trusted roots; Windows shows a confirmation dialog.

$subject = "CN=dotfiles PowerShell code signing"
$profileDir = Split-Path $PROFILE
$promptFile = Join-Path $profileDir "crocharisma.ps1"
$loadLine = '. "$PSScriptRoot\crocharisma.ps1"'

# Code-signing cert: reuse if present, otherwise create and trust it
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
  Where-Object { $_.Subject -eq $subject -and $_.NotAfter -gt (Get-Date) } |
  Sort-Object NotAfter -Descending | Select-Object -First 1
if (-not $cert) {
  $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $subject `
    -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(5)
  Write-Host "Created code-signing cert $($cert.Thumbprint)"
}
$public = [Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.Export('Cert'))
foreach ($storeName in 'Root', 'TrustedPublisher') {
  $store = [Security.Cryptography.X509Certificates.X509Store]::new($storeName, 'CurrentUser')
  $store.Open('ReadWrite')
  if (-not $store.Certificates.Find('FindByThumbprint', $cert.Thumbprint, $false).Count) {
    $store.Add($public)
    Write-Host "Trusted cert in CurrentUser\$storeName"
  }
  $store.Close()
}

# Copy the prompt next to the profile and make sure the profile loads it
New-Item -ItemType Directory -Force $profileDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot "crocharisma.ps1") $promptFile -Force
if (-not (Test-Path $PROFILE) -or -not (Select-String -Path $PROFILE -SimpleMatch $loadLine -Quiet)) {
  Add-Content -Path $PROFILE -Value $loadLine -Encoding utf8
}

foreach ($file in $promptFile, $PROFILE) {
  $sig = Set-AuthenticodeSignature -FilePath $file -Certificate $cert
  Write-Host "$($sig.Status): $file"
}
