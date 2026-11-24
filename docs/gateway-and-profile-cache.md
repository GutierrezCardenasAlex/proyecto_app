# Gateway y perfiles locales

La entrada HTTP queda como Nginx publico/admin → gateway-edge → gateway-api → servicios.
El puerto externo `GATEWAY_PORT` se conserva; el gateway usa internamente el puerto 3000.
`gateway-edge` es el unico que publica ese puerto, permitiendo replicar `gateway-api`.

En el servidor, validar antes de desplegar:

```sh
docker compose config --quiet
docker compose up -d --build --scale gateway-api=2 gateway-api gateway-edge admin-web nginx
docker compose exec gateway-edge nginx -t
```

El despliegue necesita recrear admin-web y Nginx para dirigir todas las rutas API al
limitador. No se ha ejecutado desde el entorno de desarrollo. Para volver a una
replica usar `--scale gateway-api=1`; conservar gateway-edge y sus limites.

Nginx 1.28 resuelve las replicas con el DNS interno de Docker y reparte solicitudes
segun conexiones activas. Configuracion: `infra/nginx/gateway.conf`.
Referencia: https://nginx.org/en/docs/http/ngx_http_upstream_module.html

Limites iniciales, sujetos a medicion de capacidad real:

- 20 solicitudes/segundo por credencial (IP del par para clientes anonimos), rafaga 40.
- 300 solicitudes/segundo globales, rafaga 100; 256 solicitudes concurrentes.
- Rechazo HTTP 429 con `Retry-After: 5`; conexion 3 s y lectura/escritura 30 s.
- Sin reintentos de escrituras ya enviadas ni cache compartida de perfiles privados.

Las credenciales en el limitador no sustituyen la validacion JWT del gateway.
El limite global cubre tambien credenciales inventadas/rotadas. Clientes anonimos
detras del proxy comparten presupuesto; ajustar tras medir login/OTP. No habilitar
confianza indiscriminada en X-Forwarded-For. Estos limites no garantizan capacidad:
vigilar 429, latencia, CPU, conexiones de PostgreSQL y Redis antes de aumentarlos.
Las replicas del gateway no replican los servicios ni la base de datos. WebSocket
mantiene su ruta actual y queda fuera de estos limites HTTP.

En ambas apps, el perfil y la sesion se restauran de SharedPreferences sin consultar
al servidor. La actualizacion automatica tiene un intervalo minimo de 60 segundos,
incluidos fallos de red, y evita solicitudes superpuestas. El polling de ofertas
conserva su frecuencia. La actualizacion manual del conductor fuerza la consulta.
Los cambios remotos de perfil/estado pueden tardar aproximadamente un minuto en
reflejarse; las autorizaciones reales siguen siendo responsabilidad del servidor.

Los detalles del conductor (vehiculo, licencia y referencias de fotos) se guardan
por usuario durante cinco minutos. Las comprobaciones de autorizacion consultan
siempre al servidor. Guardar el perfil invalida esos detalles y cerrar sesion los
elimina. Una respuesta de sesion recibida tras salir no repone el perfil anterior.
Los errores de red conservan el perfil previamente guardado.

Verificacion pendiente en servidor: `nginx -t`, respuestas 429 y recuperacion,
balanceo entre dos replicas y flujo real de login/viajes. No ejecutar pruebas de
carga intensivas sin autorizacion. Verificar en dispositivos que cerrar y reabrir
ambas apps conserva nombre, direccion y estado de perfil completado.
