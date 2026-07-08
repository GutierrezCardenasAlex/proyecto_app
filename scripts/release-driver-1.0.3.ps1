param(
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "rapigo.cybernovatech.space",
  [int]$RemotePort = 22,
  [string]$RemoteProjectPath = "/root/app/proyecto_app"
)

$ErrorActionPreference = "Stop"

& "$PSScriptRoot\release-driver.ps1" `
  -RemoteUser $RemoteUser `
  -RemoteHost $RemoteHost `
  -RemotePort $RemotePort `
  -RemoteProjectPath $RemoteProjectPath `
  -DriverBuildName "1.0.3" `
  -DriverBuildNumber "3" `
  -UpdatePubspecVersion

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
