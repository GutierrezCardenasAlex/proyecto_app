param(
  [string]$DeviceHost = "10.0.2.2",
  [string]$TileTemplate = "",
  [string]$Attribution = "Local tiles"
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $projectRoot "mobile\\taxiya_app"

if ([string]::IsNullOrWhiteSpace($TileTemplate)) {
  $TileTemplate = "http://$DeviceHost`:8082/styles/basic-preview/{z}/{x}/{y}.png"
}

Write-Host "Usando tiles offline:" -ForegroundColor Yellow
Write-Host $TileTemplate -ForegroundColor Cyan

Push-Location $appDir
try {
  flutter run `
    --dart-define=MAP_OFFLINE_TILES_URL_TEMPLATE=$TileTemplate `
    --dart-define=MAP_OFFLINE_TILES_ATTRIBUTION=$Attribution
}
finally {
  Pop-Location
}
