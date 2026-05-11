# Flash Go offline maps

## Opcion 1: URL configurable rapida

La app ya acepta dos modos:

- `MAP_TILES_URL_TEMPLATE`: mapa online normal
- `MAP_OFFLINE_TILES_URL_TEMPLATE`: fuente dedicada para cache/descarga offline

Si no configuras la segunda, la app sigue funcionando con OpenStreetMap sin bloquear nada.

Ejemplo manual:

```powershell
cd "C:\Users\maylex\Documents\New project\app_potosi\mobile\taxiya_app"
flutter run --dart-define=MAP_OFFLINE_TILES_URL_TEMPLATE=http://10.0.2.2:8082/styles/basic-preview/{z}/{x}/{y}.png --dart-define=MAP_OFFLINE_TILES_ATTRIBUTION="Local tiles"
```

O usando el script preparado:

```powershell
cd "C:\Users\maylex\Documents\New project\app_potosi"
.\scripts\run-flashgo-offline.ps1
```

Si usas telefono fisico, cambia `10.0.2.2` por la IP LAN de tu computadora:

```powershell
.\scripts\run-flashgo-offline.ps1 -DeviceHost 192.168.1.50
```

Si tu servidor expone otra ruta de estilo, pasala completa:

```powershell
.\scripts\run-flashgo-offline.ps1 -TileTemplate "http://192.168.1.50:8082/styles/klokantech-basic/{z}/{x}/{y}.png"
```

## Opcion 2: servidor local de tiles en Docker

El proyecto ya trae un servicio opcional `tileserver` en `docker-compose.yml`.

## Recomendacion para que sea liviano y rapido

Usa un `.mbtiles` recortado solo a `Potosi ciudad`, no a todo Bolivia.

La app ya quedo configurada para descargar una caja compacta alrededor de Potosi:

- sur-oeste: `-19.6350, -65.8050`
- nor-este: `-19.5450, -65.7050`

Eso reduce bastante la cantidad de teselas y acelera mucho la descarga offline.

Nombre sugerido del archivo:

```text
potosi-city.mbtiles
```

Si consigues o generas un `.mbtiles` mas grande que eso, seguira funcionando, pero pesara mas y tardara mas en descargar/cachear.

### 1. Coloca un `.mbtiles`

Guarda tu archivo en:

```text
infra/tiles/
```

### 2. Levanta el servidor

```powershell
cd "C:\Users\maylex\Documents\New project\app_potosi"
docker compose --profile offline-maps up -d tileserver
```

### 3. Verifica la URL real

Abre:

```text
http://localhost:8082
```

TileServer GL te mostrara las rutas de estilos/tiles disponibles. Toma una URL raster compatible con `flutter_map`.

## Resultado esperado

Cuando la app se compile con una URL offline propia:

- OpenStreetMap puede seguir como mapa online por defecto
- desaparece el bloqueo duro de descarga offline
- el boton de descarga funciona
- el cache offline de Potosi ciudad ya se puede guardar en el telefono

## Nota importante

La app bloquea descargas cuando la URL es `tile.openstreetmap.org` para evitar uso no permitido de descargas masivas desde OpenStreetMap publico.
