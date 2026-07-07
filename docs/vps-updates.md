# Actualizaciones APK desde VPS

Este proyecto publica el manifiesto en:

- `https://rapigo.cybernovatech.space/api/app-updates/manifest`
- `https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_passenger/android`
- `https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_driver_pro/android`

Y ahora sirve los APKs directamente desde Nginx en:

- `https://rapigo.cybernovatech.space/downloads/passenger/android/1.0.1/rapigo-passenger.apk`
- `https://rapigo.cybernovatech.space/downloads/driver/android/1.0.1/rapigo-driver-pro.apk`

La proxima release ya preparada en el proyecto es:

- `rapigo_passenger` -> `1.0.1+2`
- `rapigo_driver_pro` -> `1.0.1+2`

## 1. Copiar los APKs al proyecto en el VPS

Dentro del servidor, en la raiz del proyecto:

```bash
mkdir -p infra/downloads/passenger/android/1.0.1 infra/downloads/driver/android/1.0.1
cp /ruta/de/tu/rapigo-passenger.apk infra/downloads/passenger/android/1.0.1/rapigo-passenger.apk
cp /ruta/de/tu/rapigo-driver-pro.apk infra/downloads/driver/android/1.0.1/rapigo-driver-pro.apk
```

## Script unico de despliegue

Ahora puedes hacer todo con un solo comando usando:

```bash
chmod +x scripts/deploy-updates.sh
```

Ejemplo para desplegar pasajero y conductor juntos:

```bash
./scripts/deploy-updates.sh \
  --passenger-apk /root/builds/rapigo-passenger.apk \
  --passenger-version 1.0.1 \
  --passenger-build 2 \
  --passenger-released-at 2026-07-07T00:00:00Z \
  --driver-apk /root/builds/rapigo-driver-pro.apk \
  --driver-version 1.0.1 \
  --driver-build 2 \
  --driver-released-at 2026-07-07T00:00:00Z
```

Ejemplo solo conductor:

```bash
./scripts/deploy-updates.sh \
  --driver-apk /root/builds/rapigo-driver-pro.apk \
  --driver-version 1.0.2 \
  --driver-build 3 \
  --driver-released-at 2026-07-08T00:00:00Z
```

Que hace el script:

- copia los APKs a `infra/downloads/passenger/...` y `infra/downloads/driver/...`
- crea carpetas versionadas si no existen
- actualiza `services/gateway-api/src/app-updates.manifest.json`
- guarda backup del manifest anterior
- recarga Nginx automaticamente
- imprime URLs finales de verificacion

Si compilas directamente desde este repo, usa estos comandos:

```bash
cd mobile/rapigo_passenger
flutter build apk --release

cd ../rapigo_driver_pro
flutter build apk --release
```

Los APKs quedaran en:

```bash
mobile/rapigo_passenger/build/app/outputs/flutter-apk/app-release.apk
mobile/rapigo_driver_pro/build/app/outputs/flutter-apk/app-release.apk
```

## 2. Reiniciar Nginx del stack

```bash
docker compose up -d nginx
```

Si quieres recargar todo el stack:

```bash
docker compose up -d
```

## 3. Probar desde el VPS con wget

```bash
wget -O /tmp/rapigo-passenger.apk https://rapigo.cybernovatech.space/downloads/passenger/android/1.0.1/rapigo-passenger.apk
wget -O /tmp/rapigo-driver-pro.apk https://rapigo.cybernovatech.space/downloads/driver/android/1.0.1/rapigo-driver-pro.apk
```

Si prefieres validar headers:

```bash
wget -S --spider https://rapigo.cybernovatech.space/downloads/driver/android/1.0.1/rapigo-driver-pro.apk
curl -I https://rapigo.cybernovatech.space/downloads/driver/android/1.0.1/rapigo-driver-pro.apk
```

## 4. Probar el manifiesto

```bash
wget -O - https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_driver_pro/android
wget -O - https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_passenger/android
```

## 5. Errores comunes

### 404 Not Found

Significa que el APK no esta en:

- `infra/downloads/passenger/android/1.0.1/rapigo-passenger.apk`
- `infra/downloads/driver/android/1.0.1/rapigo-driver-pro.apk`

o Nginx no fue recreado/levantado otra vez.

### SSL o certificado

Si `wget` falla por certificado:

```bash
curl -Iv https://rapigo.cybernovatech.space/downloads/driver/android/1.0.1/rapigo-driver-pro.apk
```

## 6. Checklist rapido para que SI llegue la actualizacion

1. La app instalada debe ser menor que la nueva.
   Ejemplo: instalada `1.0.0+1`, nueva `1.0.1+2`.
2. El manifest debe tener `buildNumber: 2`.
3. El APK debe existir exactamente en la URL del `apkUrl`.
4. La app debe apuntar al dominio:
   `https://rapigo.cybernovatech.space/api/app-updates/manifest/...`
5. Si probaste una vez y elegiste ignorar, instala una build superior o limpia datos.

## 7. Comandos finales completos en VPS

```bash
cd /root/app/proyecto_app

mkdir -p infra/downloads/passenger/android/1.0.1
mkdir -p infra/downloads/driver/android/1.0.1

cp /ruta/de/tu/rapigo-passenger.apk infra/downloads/passenger/android/1.0.1/rapigo-passenger.apk
cp /ruta/de/tu/rapigo-driver-pro.apk infra/downloads/driver/android/1.0.1/rapigo-driver-pro.apk

docker compose up -d nginx
docker compose restart gateway-api

curl -I https://rapigo.cybernovatech.space/downloads/passenger/android/1.0.1/rapigo-passenger.apk
curl -I https://rapigo.cybernovatech.space/downloads/driver/android/1.0.1/rapigo-driver-pro.apk

curl https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_passenger/android
curl https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_driver_pro/android
```

Verifica que el dominio apunte al VPS y que el certificado este vigente.

### El manifiesto responde pero no descarga el APK

Eso pasa cuando `apkUrl` apunta a otra ruta o dominio. Revisa:

- `services/gateway-api/src/app-updates.manifest.json`

## 6. Publicar una nueva version

1. Genera el nuevo APK.
2. Reemplaza el archivo en su carpeta:
   - `infra/downloads/passenger/android/<version>/`
   - `infra/downloads/driver/android/<version>/`
3. Actualiza en `app-updates.manifest.json`:
   - `version`
   - `buildNumber`
   - `releasedAt`
   - `updatedAt`
   - `mandatory` si quieres forzar
   - `apkUrl` con la nueva carpeta versionada
4. Reinicia `gateway-api` y `nginx`:

```bash
docker compose up -d gateway-api nginx
```
