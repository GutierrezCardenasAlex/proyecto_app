param(
  [Parameter(Mandatory=$true)][ValidateSet('driver','passenger')][string]$App,
  [Parameter(Mandatory=$true)][string]$ConfigFile,
  [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$repoPath = Split-Path $PSScriptRoot -Parent
$appFolder = if ($App -eq 'driver') { 'rapigo_driver_pro' } else { 'rapigo_passenger' }
$projectPath = Join-Path $repoPath "mobile/$appFolder"
$configPath = (Resolve-Path -LiteralPath $ConfigFile).Path
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ($config.SERVER_SCHEME -ne 'https' -or $config.ROUTING_SCHEME -ne 'https') {
  throw 'API y rutas deben usar HTTPS.'
}
foreach ($name in @('SERVER_HOST','GATEWAY_PORT','WEBSOCKET_PORT','ROUTING_HOST','ROUTING_PORT','ROUTING_PATH')) {
  if ([string]::IsNullOrWhiteSpace($config.$name)) { throw "Falta configurar $name." }
}
foreach ($name in @('PRIVACY_POLICY_URL','ACCOUNT_DELETION_URL')) {
  $uri = $null
  if (-not [Uri]::TryCreate([string]$config.$name, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
    throw "$name debe ser una página pública HTTPS válida."
  }
}
if (-not (Test-Path -LiteralPath (Join-Path $projectPath 'android/key.properties'))) {
  throw 'Falta android/key.properties con la clave privada de carga. No se usará firma debug.'
}
if ($ValidateOnly) { Write-Output 'Configuración local validada; falta comprobar URLs, servicios, firma y políticas en Play Console.'; exit 0 }
Push-Location $projectPath
try {
  & flutter build appbundle --release "--dart-define-from-file=$configPath" --dart-define=PLAY_STORE=true
  if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación del AAB.' }
} finally { Pop-Location }
