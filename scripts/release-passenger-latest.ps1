param(
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "rapigo.cybernovatech.space",
  [int]$RemotePort = 22,
  [string]$RemoteProjectPath = "/root/app/proyecto_app"
)

$ErrorActionPreference = "Stop"

# Edita solo estos dos valores para tu siguiente release.
$PassengerBuildName = "1.0.5"
$PassengerBuildNumber = "5"

& "$PSScriptRoot\release-passenger.ps1" `
  -RemoteUser $RemoteUser `
  -RemoteHost $RemoteHost `
  -RemotePort $RemotePort `
  -RemoteProjectPath $RemoteProjectPath `
  -PassengerBuildName $PassengerBuildName `
  -PassengerBuildNumber $PassengerBuildNumber `
  -UpdatePubspecVersion

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
