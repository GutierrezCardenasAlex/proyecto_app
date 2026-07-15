param(
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "rapigo.cybernovatech.space",
  [int]$RemotePort = 22,
  [string]$RemoteProjectPath = "/root/app/proyecto_app"
)

$ErrorActionPreference = "Stop"

& "$PSScriptRoot\release-passenger.ps1" `
  -RemoteUser $RemoteUser `
  -RemoteHost $RemoteHost `
  -RemotePort $RemotePort `
  -RemoteProjectPath $RemoteProjectPath `
  -PassengerBuildName "1.0.2" `
  -PassengerBuildNumber "3" `
  -UpdatePubspecVersion

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
