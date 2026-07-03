# Actualizaciones APK desde VPS

Este proyecto publica el manifiesto en:

- `https://rapigo.cybernovatech.space/api/app-updates/manifest`
- `https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_passenger/android`
- `https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_driver_pro/android`

Y ahora sirve los APKs directamente desde Nginx en:

- `https://rapigo.cybernovatech.space/downloads/rapigo-passenger.apk`
- `https://rapigo.cybernovatech.space/downloads/rapigo-driver-pro.apk`

## 1. Copiar los APKs al proyecto en el VPS

Dentro del servidor, en la raiz del proyecto:

```bash
mkdir -p infra/downloads
cp /ruta/de/tu/rapigo-passenger.apk infra/downloads/rapigo-passenger.apk
cp /ruta/de/tu/rapigo-driver-pro.apk infra/downloads/rapigo-driver-pro.apk
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
wget -O /tmp/rapigo-passenger.apk https://rapigo.cybernovatech.space/downloads/rapigo-passenger.apk
wget -O /tmp/rapigo-driver-pro.apk https://rapigo.cybernovatech.space/downloads/rapigo-driver-pro.apk
```

Si prefieres validar headers:

```bash
wget -S --spider https://rapigo.cybernovatech.space/downloads/rapigo-driver-pro.apk
curl -I https://rapigo.cybernovatech.space/downloads/rapigo-driver-pro.apk
```

## 4. Probar el manifiesto

```bash
wget -O - https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_driver_pro/android
wget -O - https://rapigo.cybernovatech.space/api/app-updates/manifest/rapigo_passenger/android
```

## 5. Errores comunes

### 404 Not Found

Significa que el APK no esta en:

- `infra/downloads/rapigo-passenger.apk`
- `infra/downloads/rapigo-driver-pro.apk`

o Nginx no fue recreado/levantado otra vez.

### SSL o certificado

Si `wget` falla por certificado:

```bash
curl -Iv https://rapigo.cybernovatech.space/downloads/rapigo-driver-pro.apk
```

Verifica que el dominio apunte al VPS y que el certificado este vigente.

### El manifiesto responde pero no descarga el APK

Eso pasa cuando `apkUrl` apunta a otra ruta o dominio. Revisa:

- `services/gateway-api/src/app-updates.manifest.json`

## 6. Publicar una nueva version

1. Genera el nuevo APK.
2. Reemplaza el archivo en `infra/downloads/`.
3. Actualiza en `app-updates.manifest.json`:
   - `version`
   - `buildNumber`
   - `releasedAt`
   - `updatedAt`
   - `mandatory` si quieres forzar
4. Reinicia `gateway-api` y `nginx`:

```bash
docker compose up -d gateway-api nginx
```
