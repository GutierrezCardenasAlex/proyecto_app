param(
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "rapigo.cybernovatech.space",
  [int]$RemotePort = 22,
  [string]$RemoteProjectPath = "/root/app/proyecto_app"
)

$ErrorActionPreference = "Stop"

& "$PSScriptRoot\release.ps1" `
  -Target driver `
  -RemoteUser $RemoteUser `
  -RemoteHost $RemoteHost `
  -RemotePort $RemotePort `
  -RemoteProjectPath $RemoteProjectPath

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
