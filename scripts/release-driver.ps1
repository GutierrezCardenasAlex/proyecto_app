param(
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "rapigo.cybernovatech.space",
  [int]$RemotePort = 22,
  [string]$RemoteProjectPath = "/root/app/proyecto_app",
  [string]$DriverBuildName = "",
  [string]$DriverBuildNumber = "",
  [switch]$UpdatePubspecVersion
)

$ErrorActionPreference = "Stop"

& "$PSScriptRoot\release.ps1" `
  -Target driver `
  -RemoteUser $RemoteUser `
  -RemoteHost $RemoteHost `
  -RemotePort $RemotePort `
  -RemoteProjectPath $RemoteProjectPath `
  -DriverBuildName $DriverBuildName `
  -DriverBuildNumber $DriverBuildNumber `
  -UpdatePubspecVersion:$UpdatePubspecVersion

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
