param(
  [ValidateSet("passenger", "driver", "both")]
  [string]$Target = "both",
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$FlutterBin = "flutter",
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "rapigo.cybernovatech.space",
  [int]$RemotePort = 22,
  [string]$RemoteProjectPath = "/root/app/proyecto_app",
  [string]$BaseUrl = "https://rapigo.cybernovatech.space",
  [ValidateSet("reload-nginx", "restart-nginx", "restart-gateway", "restart-all", "none")]
  [string]$RestartMode = "reload-nginx",
  [string]$ReleasedAt = "",
  [string]$UpdatedAt = "",
  [string]$Mandatory = "false",
  [string]$PassengerBuildName = "",
  [string]$PassengerBuildNumber = "",
  [string]$DriverBuildName = "",
  [string]$DriverBuildNumber = "",
  [switch]$SkipPubGet,
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Utf8NoBomFile {
  param(
    [string]$Path,
    [string]$Content
  )

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Test-CommandExists {
  param([string]$CommandName)
  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw "No se encontro el comando requerido: $CommandName"
  }
}

function Get-PubspecVersionParts {
  param([string]$PubspecPath)

  $line = Select-String -Path $PubspecPath -Pattern '^version:\s*(.+)$' | Select-Object -First 1
  if (-not $line) {
    throw "No se pudo leer la version desde $PubspecPath"
  }

  $rawVersion = $line.Matches[0].Groups[1].Value.Trim()
  $parts = $rawVersion -split '\+'
  if ($parts.Count -ne 2) {
    throw "Formato de version invalido en ${PubspecPath}: $rawVersion"
  }

  return @{
    BuildName = $parts[0]
    BuildNumber = $parts[1]
  }
}

function Invoke-FlutterBuild {
  param(
    [string]$AppDir,
    [string]$BuildName,
    [string]$BuildNumber
  )

  Push-Location $AppDir
  try {
    if (-not $SkipPubGet.IsPresent) {
      & $FlutterBin pub get
      if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get fallo en $AppDir"
      }
    }

    & $FlutterBin build apk --release --build-name=$BuildName --build-number=$BuildNumber
    if ($LASTEXITCODE -ne 0) {
      throw "flutter build apk fallo en $AppDir"
    }
  } finally {
    Pop-Location
  }
}

function New-RemoteShellArgument {
  param([string]$Value)
  return "'" + ($Value -replace "'", "'""'""'") + "'"
}

Test-CommandExists -CommandName $FlutterBin
Test-CommandExists -CommandName "ssh"
Test-CommandExists -CommandName "scp"

$passengerAppDir = Join-Path $ProjectRoot "mobile\rapigo_passenger"
$driverAppDir = Join-Path $ProjectRoot "mobile\rapigo_driver_pro"

if ($Target -eq "passenger" -or $Target -eq "both") {
  $passengerVersion = Get-PubspecVersionParts -PubspecPath (Join-Path $passengerAppDir "pubspec.yaml")
  if (-not $PassengerBuildName) { $PassengerBuildName = $passengerVersion.BuildName }
  if (-not $PassengerBuildNumber) { $PassengerBuildNumber = $passengerVersion.BuildNumber }
}

if ($Target -eq "driver" -or $Target -eq "both") {
  $driverVersion = Get-PubspecVersionParts -PubspecPath (Join-Path $driverAppDir "pubspec.yaml")
  if (-not $DriverBuildName) { $DriverBuildName = $driverVersion.BuildName }
  if (-not $DriverBuildNumber) { $DriverBuildNumber = $driverVersion.BuildNumber }
}

if (-not $ReleasedAt) {
  $ReleasedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

if (-not $UpdatedAt) {
  $UpdatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$localArtifacts = @{}

if (-not $SkipBuild.IsPresent) {
  if ($Target -eq "passenger" -or $Target -eq "both") {
    Write-Step "Construyendo RAPIGO pasajero $PassengerBuildName+$PassengerBuildNumber"
    Invoke-FlutterBuild -AppDir $passengerAppDir -BuildName $PassengerBuildName -BuildNumber $PassengerBuildNumber
  }

  if ($Target -eq "driver" -or $Target -eq "both") {
    Write-Step "Construyendo RAPIGO PRO conductor $DriverBuildName+$DriverBuildNumber"
    Invoke-FlutterBuild -AppDir $driverAppDir -BuildName $DriverBuildName -BuildNumber $DriverBuildNumber
  }
}

if ($Target -eq "passenger" -or $Target -eq "both") {
  $passengerApk = Join-Path $passengerAppDir "build\app\outputs\flutter-apk\app-release.apk"
  if (-not (Test-Path $passengerApk)) {
    throw "No existe APK de pasajero en $passengerApk"
  }
  $localArtifacts["passenger"] = $passengerApk
}

if ($Target -eq "driver" -or $Target -eq "both") {
  $driverApk = Join-Path $driverAppDir "build\app\outputs\flutter-apk\app-release.apk"
  if (-not (Test-Path $driverApk)) {
    throw "No existe APK de conductor en $driverApk"
  }
  $localArtifacts["driver"] = $driverApk
}

$remoteSession = "$RemoteUser@$RemoteHost"
$releaseStamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
$remoteUploadDir = "/tmp/rapigo-release-$releaseStamp"

Write-Step "Probando conexion SSH a $remoteSession`:$RemotePort"
& ssh -p $RemotePort $remoteSession "echo ok"
if ($LASTEXITCODE -ne 0) {
  throw "No se pudo conectar por SSH a ${remoteSession}:${RemotePort}. Verifica llave, usuario, puerto y DNS."
}

Write-Step "Preparando carpeta remota $remoteUploadDir"
& ssh -p $RemotePort $remoteSession "mkdir -p $remoteUploadDir"
if ($LASTEXITCODE -ne 0) {
  throw "No se pudo crear la carpeta remota $remoteUploadDir"
}

if ($localArtifacts.ContainsKey("passenger")) {
  Write-Step "Subiendo APK pasajero a VPS"
  & scp -P $RemotePort $localArtifacts["passenger"] "${remoteSession}:${remoteUploadDir}/rapigo-passenger.apk"
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo la subida del APK de pasajero"
  }
}

if ($localArtifacts.ContainsKey("driver")) {
  Write-Step "Subiendo APK conductor a VPS"
  & scp -P $RemotePort $localArtifacts["driver"] "${remoteSession}:${remoteUploadDir}/rapigo-driver-pro.apk"
  if ($LASTEXITCODE -ne 0) {
    throw "Fallo la subida del APK de conductor"
  }
}

$deployArgs = New-Object System.Collections.Generic.List[string]
$deployArgs.Add("./scripts/deploy-updates.sh")
$deployArgs.Add("--base-url")
$deployArgs.Add((New-RemoteShellArgument $BaseUrl))
$deployArgs.Add("--restart-mode")
$deployArgs.Add((New-RemoteShellArgument $RestartMode))

if ($localArtifacts.ContainsKey("passenger")) {
  $deployArgs.Add("--passenger-apk")
  $deployArgs.Add((New-RemoteShellArgument "$remoteUploadDir/rapigo-passenger.apk"))
  $deployArgs.Add("--passenger-version")
  $deployArgs.Add((New-RemoteShellArgument $PassengerBuildName))
  $deployArgs.Add("--passenger-build")
  $deployArgs.Add((New-RemoteShellArgument $PassengerBuildNumber))
  $deployArgs.Add("--passenger-released-at")
  $deployArgs.Add((New-RemoteShellArgument $ReleasedAt))
  $deployArgs.Add("--passenger-updated-at")
  $deployArgs.Add((New-RemoteShellArgument $UpdatedAt))
  $deployArgs.Add("--passenger-mandatory")
  $deployArgs.Add((New-RemoteShellArgument $Mandatory))
}

if ($localArtifacts.ContainsKey("driver")) {
  $deployArgs.Add("--driver-apk")
  $deployArgs.Add((New-RemoteShellArgument "$remoteUploadDir/rapigo-driver-pro.apk"))
  $deployArgs.Add("--driver-version")
  $deployArgs.Add((New-RemoteShellArgument $DriverBuildName))
  $deployArgs.Add("--driver-build")
  $deployArgs.Add((New-RemoteShellArgument $DriverBuildNumber))
  $deployArgs.Add("--driver-released-at")
  $deployArgs.Add((New-RemoteShellArgument $ReleasedAt))
  $deployArgs.Add("--driver-updated-at")
  $deployArgs.Add((New-RemoteShellArgument $UpdatedAt))
  $deployArgs.Add("--driver-mandatory")
  $deployArgs.Add((New-RemoteShellArgument $Mandatory))
}

$remoteDeployCommand = @(
  "#!/usr/bin/env bash"
  "set -euo pipefail"
  "cd $(New-RemoteShellArgument $RemoteProjectPath)"
  "chmod +x ./scripts/deploy-updates.sh"
  ($deployArgs -join " ")
) -join "`n"

$localRemoteScript = Join-Path ([System.IO.Path]::GetTempPath()) "rapigo-remote-release-$releaseStamp.sh"
Write-Utf8NoBomFile -Path $localRemoteScript -Content $remoteDeployCommand

Write-Step "Subiendo script remoto de despliegue"
& scp -P $RemotePort $localRemoteScript "${remoteSession}:${remoteUploadDir}/run-release.sh"
if ($LASTEXITCODE -ne 0) {
  throw "No se pudo subir el script remoto de despliegue"
}

Write-Step "Ejecutando deploy remoto"
& ssh -p $RemotePort $remoteSession "chmod +x ${remoteUploadDir}/run-release.sh && ${remoteUploadDir}/run-release.sh"
if ($LASTEXITCODE -ne 0) {
  throw "Fallo el despliegue remoto en la VPS"
}

Write-Step "Limpiando archivos temporales remotos"
& ssh -p $RemotePort $remoteSession "rm -rf ${remoteUploadDir}"

if (Test-Path $localRemoteScript) {
  Remove-Item $localRemoteScript -Force
}

Write-Host ""
Write-Host "Release completado." -ForegroundColor Green
Write-Host "Host: $RemoteHost" -ForegroundColor Yellow
if ($localArtifacts.ContainsKey("passenger")) {
  Write-Host "Passenger: $PassengerBuildName+$PassengerBuildNumber" -ForegroundColor Cyan
}
if ($localArtifacts.ContainsKey("driver")) {
  Write-Host "Driver: $DriverBuildName+$DriverBuildNumber" -ForegroundColor Cyan
}
