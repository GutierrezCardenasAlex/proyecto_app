param(
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "rapigo.cybernovatech.space",
  [int]$RemotePort = 22,
  [string]$RemoteProjectPath = "/root/app/proyecto_app",
  [string]$PassengerBuildName = "",
  [string]$PassengerBuildNumber = "",
  [switch]$UpdatePubspecVersion
)

$ErrorActionPreference = "Stop"

& "$PSScriptRoot\release.ps1" `
  -Target passenger `
  -RemoteUser $RemoteUser `
  -RemoteHost $RemoteHost `
  -RemotePort $RemotePort `
  -RemoteProjectPath $RemoteProjectPath `
  -PassengerBuildName $PassengerBuildName `
  -PassengerBuildNumber $PassengerBuildNumber `
  -UpdatePubspecVersion:$UpdatePubspecVersion

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
