Coloca aqui tu archivo `.mbtiles` para habilitar el servidor local de tiles.

Pasos recomendados:
1. Descarga o genera un tileset propio de Potosi o Bolivia en formato `.mbtiles`.
2. Guarda el archivo dentro de esta carpeta, por ejemplo `potosi.mbtiles`.
3. Levanta el servidor local:

```powershell
docker compose --profile offline-maps up -d tileserver
```

4. Abre en tu navegador:

```text
http://localhost:8082
```

Desde esa pagina veras las rutas reales disponibles para tiles raster/estilos. Usa una de esas rutas como `MAP_TILES_URL_TEMPLATE` al correr Flutter.

Ejemplo frecuente:

```text
http://10.0.2.2:8082/styles/basic-preview/{z}/{x}/{y}.png
```

Nota:
- `10.0.2.2` sirve para Android Emulator.
- En telefono fisico usa la IP LAN de tu PC, por ejemplo `http://192.168.1.50:8082/...`
- La URL exacta puede variar segun el tileset y el estilo expuesto por TileServer GL.
