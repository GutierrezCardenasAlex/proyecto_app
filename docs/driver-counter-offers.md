# Solicitudes y ofertas de varios conductores

En **Pedir taxi**, la solicitud se difunde inmediatamente a los conductores disponibles. La lista del conductor se consulta desde PostgreSQL y no desaparece porque caduque una notificación Redis. El conductor entra a Solicitudes, revisa recogida, destino, precio y ruta, y envía una oferta. Revisar la ruta no asigna el viaje. Aceptar el precio original sí asigna el viaje inmediatamente; proponer un precio distinto espera aprobación del pasajero.

El pasajero compara las ofertas con precio, nombre, calificación, vehículo y placa. **Ignorar** descarta solo esa oferta; no cancela la solicitud. **Elegir conductor** asigna el viaje y la tarifa dentro de una transacción, pasa a `arriving` y abre el flujo de recogida del conductor elegido. Las ofertas competidoras quedan fuera de disponibilidad. Un conductor no puede quedar asignado a dos viajes.

En **Tomar taxi**, si se eligió un conductor en el mapa, ese conductor puede enviar su oferta y el pasajero puede elegirla o ignorarla. Sin un conductor específico, la solicitud está abierta. El botón **Ver ofertas** permite volver a la lista mientras se espera.

Cada conductor mantiene una oferta por solicitud. Puede actualizar el precio pendiente, pero no reenviar una oferta que el pasajero ya ignoró. El servidor verifica el precio que el pasajero vio y la versión exacta del recorrido; un cambio de ruta invalida las ofertas anteriores hasta que se reenvíen. Las promociones conservan su tarifa. Las ofertas no tienen un vencimiento ficticio de 20 segundos.

El botón **Aceptar Bs 10.00** del conductor envía la propuesta sin otro precio: el servidor conserva la tarifa del pasajero. **Enviar una oferta** permite proponer, por ejemplo, Bs 15; el pasajero recibe ese precio y elige o ignora al conductor. Solo el precio distinto espera la elección del pasajero. Aceptar Bs 10 confirma inmediatamente, sin pedir una segunda aprobación; funciona en Pedir taxi y Tomar taxi.

Se retiraron el cronómetro, el filtro de ofertas vencidas de la app y el despacho secuencial con temporizador. La notificación inicial de Pedir taxi incluye a todos los conductores disponibles que aceptan transporte, aunque todavía no tengan una ubicación GPS reciente. La ubicación reciente sigue siendo necesaria para mostrar vehículos en el mapa. Las solicitudes permanecen consultables mientras estén abiertas, incluso después de vencer la caché de notificaciones.

## API y despliegue

- `POST /dispatch/proposals`: recibe `tripId`, `driverId` y `counterFare` opcional. Si el precio coincide con el del pasajero (o se omite `counterFare`), devuelve `{ proposal, accepted: true, trip }` y asigna el viaje en una transacción. Para un precio distinto devuelve `{ proposal, accepted: false }` con estado `pending`. `expectedFare` permite rechazar una aceptación si cambió la tarifa vista por el conductor. La app valida ambas respuestas y abre inmediatamente la confirmación de la aceptación directa.
- `/dispatch/accept` queda como alias para clientes anteriores contra el servidor actualizado. La nueva app nunca utiliza esa ruta ni recurre a ella si `/proposals` no existe: en servidores antiguos podía asignar el viaje inmediatamente. Una respuesta 404/405 pide actualizar el servidor, sin intentar aceptar el viaje.
- `GET /trips/:tripId/offers`: ofertas vigentes para el pasajero propietario.
- `POST /trips/:tripId/offers/:offerId/response`: `{ accept, expectedAmount }`; el importe observado es obligatorio para elegir.
- La consulta del viaje activo del pasajero incluye `offers` para recuperación al reconectar y reiniciar.
- Eventos: `trip:offers_changed`, `driver:offers_changed`, y los eventos de estado/asignación existentes al confirmar.

Los servicios crean `trip_driver_offers` al arrancar. El esquema de instalaciones nuevas incluye la misma tabla. Actualizar **trip-service, dispatch-service y ambas apps juntos**, porque cambió el contrato de `/dispatch/accept`. No se desplegaron servicios ni se instalaron APK durante esta modificación. El flujo anterior de contraoferta única permanece disponible únicamente para terminar solicitudes antiguas que ya estuvieran reservadas.

## Verificación

- `flutter test --no-pub` y `flutter analyze --no-pub` en cada app.
- `node --test services/trip-service/test/counter-offers.test.js` conserva la compatibilidad anterior.
- `OFFER_TEST_DATABASE_URL` debe apuntar exclusivamente a PostgreSQL de pruebas. Con esa variable, ejecutar `node --test services/trip-service/test/driver-offers.integration.test.js`. La prueba crea y elimina un esquema propio y usa las transacciones reales, sin arrancar los servicios productivos.

Se verifican ofertas simultáneas sin reserva, selección de un único conductor, rechazo de una doble asignación entre viajes, ignorar sin cancelar, cambios de tarifa/recorrido, solicitudes canceladas y el modo dirigido de Tomar taxi. Redis y WebSocket se simulan en esa prueba; queda pendiente comprobar el recorrido completo con ambas apps en teléfonos conectados al backend actualizado.
