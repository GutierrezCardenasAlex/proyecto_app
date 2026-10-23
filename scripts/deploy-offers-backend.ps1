param(
  [string]$RemoteHost = 'rapigo-vps',
  [string]$RemoteProjectPath = '/root/app/proyecto_app',
  [switch]$PrepareOnly
)

$ErrorActionPreference = 'Stop'
if ($RemoteHost -notmatch '^[a-zA-Z0-9_.@-]+$' -or $RemoteHost.StartsWith('-')) {
  throw 'Host SSH invalido.'
}
if ($RemoteProjectPath -notmatch '^/[a-zA-Z0-9_./-]+$' -or $RemoteProjectPath.Contains('..')) {
  throw 'Ruta remota invalida.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseId = 'rapigo-offers-' + [guid]::NewGuid().ToString('N')
$stage = Join-Path ([System.IO.Path]::GetTempPath()) $releaseId
New-Item -ItemType Directory -Path $stage | Out-Null
$archive = Join-Path $stage 'backend.tar.gz'
$sources = @(
  'services/dispatch-service/src', 'services/dispatch-service/package.json', 'services/dispatch-service/Dockerfile',
  'services/trip-service/src', 'services/trip-service/package.json', 'services/trip-service/Dockerfile'
)
& tar -czf $archive -C $projectRoot @sources
if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el backend.' }

$remoteScript = @'
#!/usr/bin/env bash
set -euo pipefail
project="$1"
bundle="$(cd "$(dirname "$0")" && pwd)"
cd "$project"
test -f docker-compose.yml
docker compose config --services | grep -qx dispatch-service
docker compose config --services | grep -qx trip-service
backup="$project/backups/$(basename "$bundle")"
mkdir -p "$backup"
tar -czf "$backup/backend-before.tar.gz" \
  services/dispatch-service/src services/dispatch-service/package.json services/dispatch-service/Dockerfile \
  services/trip-service/src services/trip-service/package.json services/trip-service/Dockerfile
echo "Respaldo: $backup/backend-before.tar.gz"
tar -xzf "$bundle/backend.tar.gz" -C "$project"
docker compose build dispatch-service trip-service
docker compose up -d --no-deps dispatch-service trip-service
for service in dispatch-service trip-service; do
  ready=false
  for attempt in $(seq 1 30); do
    if docker compose exec -T "$service" node -e 'fetch("http://127.0.0.1:"+process.env.PORT+"/health").then(async r=>{if(!r.ok||(await r.json()).status!=="ok")process.exit(1)}).catch(()=>process.exit(1))'; then
      ready=true
      break
    fi
    sleep 2
  done
  if [ "$ready" != true ]; then
    echo "Servicio no disponible: $service. Respaldo conservado en $backup" >&2
    exit 1
  fi
done
# An empty proposal must be rejected before any database write, and must not be 404.
docker compose exec -T dispatch-service node -e 'fetch("http://127.0.0.1:"+process.env.PORT+"/proposals",{method:"POST",headers:{"content-type":"application/json"},body:"{}"}).then(r=>{if(r.status!==400)throw Error("Ruta de propuestas: HTTP "+r.status);console.log("Ruta /proposals disponible; solicitud invalida rechazada sin aceptar viajes.")}).catch(e=>{console.error(e.message);process.exit(1)})'
echo 'Backend de ofertas actualizado y verificado.'
'@
$installer = Join-Path $stage 'install.sh'
[System.IO.File]::WriteAllText($installer, $remoteScript.Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
Write-Host "Paquete preparado: $stage"
if ($PrepareOnly) { return }

# Run in an interactive terminal so SSH can request the user's password if needed.
& ssh $RemoteHost "mkdir -p /tmp/$releaseId"
if ($LASTEXITCODE -ne 0) { throw 'SSH rechazo el acceso. No se modifico el servidor.' }
& scp $archive $installer "${RemoteHost}:/tmp/$releaseId/"
if ($LASTEXITCODE -ne 0) { throw 'No se pudo subir el paquete.' }
& ssh $RemoteHost "bash /tmp/$releaseId/install.sh '$RemoteProjectPath'"
if ($LASTEXITCODE -ne 0) { throw 'El despliegue no termino correctamente. Revisa la salida y el respaldo indicado.' }
