# Contraofertas y menú del conductor

El conductor puede proponer un precio mayor al original desde una solicitud entrante no promocional. El servidor reserva el viaje y al conductor con el estado existente `accepted` y `counter_offer_status = pending`. La tarifa original se conserva hasta que el pasajero responda. Los clientes muestran la espera y el servidor impide avanzar a recogida, inicio o finalización durante esa espera.

- Aceptar: guarda `counter_offer_amount` como `fare_amount` y pasa a `arriving`.
- Rechazar: cancela el viaje y libera al conductor dentro de la misma transacción.
- El conductor también puede cancelar mientras espera. No se acepta una respuesta posterior a la cancelación.
- Una contraoferta pendiente se recupera desde el servidor y la caché local al reabrir las apps. No tiene vencimiento automático: requiere respuesta o cancelación.

API: `POST /dispatch/accept` admite el campo opcional `counterFare`. `POST /trips/:tripId/counter-offer/response` recibe `{ "accept": true }` o `{ "accept": false }` y exige la identidad del pasajero propietario. Se notifican ambos clientes mediante `trip:counter_offer` y `driver:counter_offer`; también existe recuperación por consultas periódicas.

## Puesta en funcionamiento

Actualizar y reiniciar `trip-service` y `dispatch-service` antes de distribuir las dos apps actualizadas. Los servicios añaden las columnas de forma idempotente al arrancar; el esquema para instalaciones nuevas también las incluye. Esta modificación no despliega servicios ni instala APK en teléfonos.

## Verificación

Pruebas automatizadas:

- `node --test services/trip-service/test/counter-offers.test.js`
- `flutter test --no-pub` dentro de cada app.
- `flutter analyze --no-pub` dentro de cada app.

Las pruebas del servidor usan dependencias simuladas; no reemplazan una prueba con PostgreSQL, Redis, WebSocket y ambos teléfonos conectados.

Comprobar en un entorno de prueba: ofrecer Bs 10, proponer Bs 15, aceptar y confirmar que ambos muestran Bs 15 y pueden seguir el viaje; repetir rechazando y verificar que se cancela y el conductor queda libre. Probar dos conductores sobre la misma solicitud, cancelación simultánea con una respuesta, pérdida de conexión y reapertura de ambas apps durante la espera.

El inicio del conductor muestra la calle abajo y un FAB a la derecha con centro del conductor, vista del vehículo/mapa y solicitudes. La calle se consulta de nuevo cuando cambia la ubicación al menos 22 metros.
