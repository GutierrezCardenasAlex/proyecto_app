param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Docker {
  try {
    docker version | Out-Null
  } catch {
    throw "Docker no esta disponible en este entorno."
  }
}

function Invoke-ComposePs {
  docker compose ps --format json | ConvertFrom-Json
}

function Test-ContainerStatus {
  param([object[]]$Containers)

  $required = @(
    "postgres",
    "redis",
    "rabbitmq",
    "auth-service",
    "driver-service",
    "trip-service",
    "dispatch-service",
    "location-service",
    "notification-service",
    "admin-service",
    "websocket-service",
    "gateway-api"
  )

  $failed = @()
  foreach ($service in $required) {
    $container = $Containers | Where-Object { $_.Service -eq $service } | Select-Object -First 1
    if (-not $container) {
      $failed += "No existe contenedor para $service"
      continue
    }

    if ($container.State -ne "running") {
      $failed += "$service no esta corriendo. Estado: $($container.State)"
    }
  }

  if ($failed.Count -gt 0) {
    $failed | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw "Hay contenedores detenidos o faltantes."
  }
}

function Test-ServiceHealth {
  param(
    [string]$TargetUrl,
    [string]$Label
  )

  $script = @"
const url = process.argv[1];
fetch(url)
  .then(async (res) => {
    const text = await res.text();
    if (!res.ok) {
      console.error(`${res.status} ${text}`);
      process.exit(1);
    }
    console.log(text);
  })
  .catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
"@

  $result = docker compose exec -T gateway-api node -e $script $TargetUrl 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Fallo healthcheck: $Label -> $result" -ForegroundColor Red
    throw "Healthcheck fallido para $Label"
  }

  Write-Host "$Label OK" -ForegroundColor Green
}

Set-Location $ProjectRoot

Write-Step "Validando Docker"
Test-Docker

Write-Step "Revisando contenedores"
$containers = Invoke-ComposePs
$containers | Format-Table Service, State, Status -AutoSize
Test-ContainerStatus -Containers $containers

Write-Step "Revisando health internos"
Test-ServiceHealth -TargetUrl "http://auth-service:3001/health" -Label "auth-service"
Test-ServiceHealth -TargetUrl "http://driver-service:3002/health" -Label "driver-service"
Test-ServiceHealth -TargetUrl "http://trip-service:3003/health" -Label "trip-service"
Test-ServiceHealth -TargetUrl "http://dispatch-service:3004/health" -Label "dispatch-service"
Test-ServiceHealth -TargetUrl "http://location-service:3005/health" -Label "location-service"
Test-ServiceHealth -TargetUrl "http://notification-service:3006/health" -Label "notification-service"
Test-ServiceHealth -TargetUrl "http://admin-service:3007/health" -Label "admin-service"
Test-ServiceHealth -TargetUrl "http://websocket-service:3008/health" -Label "websocket-service"

Write-Step "Revisando gateway"
try {
  $gatewayHealth = Invoke-RestMethod -Uri "http://localhost:3000/health" -Method Get
  Write-Host "gateway-api OK -> $($gatewayHealth.service)" -ForegroundColor Green
} catch {
  throw "gateway-api no responde en http://localhost:3000/health"
}

Write-Step "Revisando infraestructura publica"
try {
  $rabbit = Invoke-WebRequest -Uri "http://localhost:15672" -UseBasicParsing -TimeoutSec 5
  Write-Host "rabbitmq management OK -> $($rabbit.StatusCode)" -ForegroundColor Green
} catch {
  Write-Host "RabbitMQ management no respondio en http://localhost:15672" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Stack verificado correctamente." -ForegroundColor Green
