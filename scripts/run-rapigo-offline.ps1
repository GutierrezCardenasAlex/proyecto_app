param(
  [string]$TileTemplate = "http://10.0.2.2:8082/styles/klokantech-basic/{z}/{x}/{y}.png",
  [string]$Attribution = "Local tiles",
  [string]$DeviceHost = ""
)

if ($DeviceHost -ne "") {
  $TileTemplate = $TileTemplate -replace "10.0.2.2", $DeviceHost
}

Write-Host "Usando tiles offline:" -ForegroundColor Yellow
Write-Host $TileTemplate -ForegroundColor Cyan

flutter run `
  --dart-define=MAP_OFFLINE_TILES_URL_TEMPLATE=$TileTemplate `
  --dart-define=MAP_OFFLINE_TILES_ATTRIBUTION="$Attribution"
