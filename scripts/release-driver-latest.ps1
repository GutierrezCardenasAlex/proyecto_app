param(
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "rapigo.cybernovatech.space",
  [int]$RemotePort = 22,
  [string]$RemoteProjectPath = "/root/app/proyecto_app"
)

$ErrorActionPreference = "Stop"

# Edita solo estos dos valores para tu siguiente release.
$DriverBuildName = "1.0.8"
$DriverBuildNumber = "8"

& "$PSScriptRoot\release-driver.ps1" `
  -RemoteUser $RemoteUser `
  -RemoteHost $RemoteHost `
  -RemotePort $RemotePort `
  -RemoteProjectPath $RemoteProjectPath `
  -DriverBuildName $DriverBuildName `
  -DriverBuildNumber $DriverBuildNumber `
  -UpdatePubspecVersion

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
