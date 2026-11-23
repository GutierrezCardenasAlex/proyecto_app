# RAPIGO offline maps

## Configuracion actual de conductor y pasajero

Conductor usa **flutter_map con OpenStreetMap raster**. MapLibre Native se
retiró de sus dependencias. El mapa conserva el movimiento suave y los límites
de Potosí. Las teselas vistas se guardan automáticamente en la caché persistente
`potosi_online_map_v3`, que se reutiliza al cerrar y abrir la app. No se borra la
caché existente al actualizar. No se descarga toda la ciudad desde OSM público.
Sin conexión solo estarán disponibles las zonas y niveles de zoom ya cargados.
Las rutas guardadas se conservan; calcular rutas nuevas puede requerir internet.

Pasajero usa por defecto el servidor propio configurado en docker-compose:
`https://rapigo.cybernovatech.space/tiles/styles/rapigo-navigation/512/{z}/{x}/{y}.png`.
CARTO ya no es el proveedor predeterminado. El motor predeterminado es raster,
que muestra las mismas teselas almacenadas por flutter_map_tile_caching.
En pasajero, MapLibre sigue siendo opcional con `RAPIGO_MAP_ENGINE=maplibre`.
Las siguientes opciones de teselas raster corresponden a fuentes propias configuradas para pasajero o conductor.

- El paquete completo se registra solamente cuando todas las teselas se guardaron
  o ya estaban en cache. La identidad incluye URL, limites, zoom y dimension.
- Al reiniciar se reutiliza el paquete completo. Una descarga parcial se reanuda
  omitiendo las teselas existentes; solo hay un intento automatico por sesion.
- El boton «Completar mapa» reintenta las faltantes sin borrar lo descargado.
- Las teselas de la fuente offline propia no caducan automaticamente. Para una
  nueva edicion del mapa, usar una URL versionada en la configuracion de compilacion.
- Actualizar la app conserva la cache; desinstalarla o borrar sus datos la elimina.
- Los registros antiguos no certificaban un paquete completo: la primera apertura
  puede verificarlo nuevamente, sin volver a bajar las teselas de la misma URL.

La primera descarga requiere que el servidor propio este disponible. Durante la
revision local su puerto HTTPS rechazo la conexion; no se pudo validar una
primera descarga real. No se incluye un archivo MBTiles en el APK: la referencia
`assets/maps/potosi.mbtiles` del manifiesto no es un importador de mapas.

Para usar otra fuente autorizada para descarga offline, establecer
`MAP_OFFLINE_TILES_URL_TEMPLATE` y `MAP_OFFLINE_TILES_ATTRIBUTION` al compilar.
Si solo se necesita navegacion online gratuita, se puede establecer
`MAP_TILES_URL_TEMPLATE=https://tile.openstreetmap.org/{z}/{x}/{y}.png` sin fuente
offline: guarda las zonas consultadas y deshabilita la descarga masiva.


## Opcion 1: URL configurable rapida

La app ya acepta dos modos:

- `MAP_TILES_URL_TEMPLATE`: mapa online normal
- `MAP_OFFLINE_TILES_URL_TEMPLATE`: fuente dedicada para cache/descarga offline

Si no configuras la segunda, la app usa la fuente principal (por defecto el servidor propio). OpenStreetMap publico solo se usa si se configura explicitamente.

Ejemplo manual:

```powershell
cd "C:\Users\maylex\Documents\New project\app_potosi\mobile\rapigo_passenger"
flutter run --dart-define=MAP_OFFLINE_TILES_URL_TEMPLATE=http://10.0.2.2:8082/styles/basic-preview/{z}/{x}/{y}.png --dart-define=MAP_OFFLINE_TILES_ATTRIBUTION="Local tiles"
```

O usando el script preparado:

```powershell
cd "C:\Users\maylex\Documents\New project\app_potosi"
.\scripts\run-rapigo-offline.ps1
```

Si usas telefono fisico, cambia `10.0.2.2` por la IP LAN de tu computadora:

```powershell
.\scripts\run-rapigo-offline.ps1 -DeviceHost 192.168.1.50
```

Si tu servidor expone otra ruta de estilo, pasala completa:

```powershell
.\scripts\run-rapigo-offline.ps1 -TileTemplate "http://192.168.1.50:8082/styles/klokantech-basic/{z}/{x}/{y}.png"
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
