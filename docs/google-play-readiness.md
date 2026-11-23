# RAPIGO y RAPIGO PRO: auditoría de publicación

Revisión: 23 de noviembre de 2026. Responsable indicado por el propietario: **Stellar Labs**. Aplicaciones: `com.rapigo.passenger` y `com.rapigo.driver`.

**Estado: todavía no aptas para enviar a producción.** Esta auditoría del repositorio no es una aprobación de Google Play ni certifica servicios desplegados. No se accedió a Play Console ni se publicaron cambios. Las páginas oficiales pueden cambiar; revisar las declaraciones de la consola al enviar cada versión.

## Cambios realizados

- Perfil de conductor con resumen diario, importes de viajes completados y lista de documentos cargados. Cargado no equivale a documento aprobado. Se conserva la autorización global de la central.
- Estadísticas sin prioridad artificial ni calificación fija. Fechas por finalización, con respaldo de fecha de solicitud para registros antiguos; no incluir fechas futuras ni importes no finitos.
- La calificación mostrada al pasajero procede del promedio de valoraciones, no del 5.0 predeterminado de la tabla. Sin valoraciones se indica expresamente.
- Estado de conexión del socket visible, separado de disponibilidad solicitada. Seguimiento del conductor mientras está disponible o con viaje activo.
- Aviso de uso de ubicación antes de pedir permisos; rechazo sin bucle obligatorio. Notificaciones opcionales. Pasajero sin permiso ni servicio de ubicación en segundo plano, suspendiendo seguimiento al salir del primer plano.
- Privacidad y solicitud de eliminación accesibles desde ambos perfiles. Las solicitudes llegan al soporte existente como `eliminacion_cuenta`, con confirmación real del servidor. **No constituye borrado automático.**
- Planes y vigencias de suscripción administrados en Configuración de la central. Importes en BOB, duración y estado editables; autorizaciones con referencia única, términos originales y renovaciones acumuladas. Pantalla de consulta en RAPIGO PRO.
- Edición Play mediante `PLAY_STORE=true`: sin permiso de instalar paquetes ni actualizador APK, sin tráfico HTTP, sin copia de seguridad Android y con firma privada obligatoria. API objetivo mínima 36.
- Autenticación de producción: sin OTP en respuesta y sin secretos de demostración; SMS real requerido. Esto no sustituye una auditoría completa del backend.

## Bloqueos antes de publicar

| Área | Hallazgo / acción pendiente |
|---|---|
| Identidad de la organización | Confirmar denominación legal exacta, domicilio, contacto y tipo de cuenta Play. “Stellar Labs” es la información proporcionada; no se verificó su registro. |
| Política pública | Falta correo y URL pública definitiva. Completar datos, proveedores, retención y derechos; alojar una página accesible y enlazarla en ambas apps y fichas. El resumen dentro de la app no reemplaza la política completa. |
| Eliminación real | La ruta administrativa actual `DELETE /users/:userId` rechaza usuarios con viajes. Implementar eliminación/anominización verificable de perfiles, fotos en Cloudinary, ubicaciones, tokens, cachés, reportes y datos relacionados. Definir retención legal antes de conservar datos; no basta bloquear o cerrar sesión. |
| Eliminación web | Publicar un mecanismo externo funcional, identificar al solicitante de forma proporcionada y conectar el flujo a soporte. No presentar una página informativa vacía como mecanismo de solicitud. |
| Suscripciones | El propietario gestiona precios desde la central. Falta definir medio de cobro, comprobación, devoluciones, cancelación y términos. La implementación actual registra vigencias; **no cobra, no renueva automáticamente y no bloquea solicitudes por vencimiento**. No anunciar esas funciones como terminadas. |
| Billing | Distinguir pago del transporte físico de pago por acceso a funciones digitales. No asumir que una suscripción de software está exenta. La pantalla Play es de consulta, sin QR ni enlaces para comprar fuera. Resolver la clasificación y, si aplica, integrar Play Billing con validación en servidor antes de vender dentro de la app. |
| Firma | No hay AAB de producción validado. Configurar la clave de carga fuera de Git, Play App Signing y resguardo de la clave. No reemplazar una clave de distribución existente sin revisar compatibilidad con instalaciones actuales. |
| Infraestructura | Verificar HTTPS/WSS y certificados reales para API, sockets, rutas y mapas. Los scripts antiguos de distribución directa no convierten automáticamente una instalación en edición Play. |
| Seguridad del servicio | Revisar autorización por usuario de todos los endpoints, salas WebSocket, rate limiting de OTP/login, expiración/revocación de tokens, registros, backups y acceso privado a documentos. La revisión local no demuestra esas garantías en producción. |
| Acceso de revisores | Proveer cuentas y pasos de acceso para ambas apps, incluyendo aprobación de dispositivo/conductor y restricciones de Potosí. No crear bypass oculto de producción. El revisor debe poder completar el flujo sin depender de respuestas manuales. |
| Dispositivos | Probar viaje completo con dos dispositivos, pérdida de red, cierre/reapertura, ubicación aproximada/denegada, Android 16, texto grande y bibliotecas nativas de 16 KB. Verificar el AAB final y el informe previo al lanzamiento. |

## Matriz de políticas aplicables

| Política / requisito | Aplicación a RAPIGO | Evidencia / acción |
|---|---|---|
| Datos personales, transparencia y seguridad | Ambas apps usan cuenta, contacto, ubicación y viajes; conductor añade documentación. | Inventario abajo; completar política, consentimiento y Data safety con comportamiento efectivo de terceros. [User Data](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en) |
| Eliminación de cuenta | Hay registro desde la app. | Requiere ruta interna y externa y atender datos asociados; la solicitud a soporte es solo el inicio. [Eliminación](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) |
| API objetivo | Aplicaciones Android de teléfono nuevas/actualizaciones. | Desde 31/08/2026 se exige API 36; configurado mínimo 36. [Target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en) |
| Ubicación | Conductor requiere seguimiento; pasajero usa primer plano. | Grabar demostración real del aviso, permiso y función del conductor. Confirmar mínima precisión necesaria y comportamiento con permiso aproximado. [Ubicación en segundo plano](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en) |
| Servicio en primer plano | Servicio de ubicación del conductor. | Declarar tipo `location`, propósito, impacto y demostración en Play Console; validar manifiesto fusionado. [FGS](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en) |
| Instalación de paquetes | El distribuidor directo contiene actualizador APK. | Excluido por manifiesto y lógica en edición Play. Verificar también código nativo y manifiesto final. [REQUEST_INSTALL_PACKAGES](https://support.google.com/googleplay/android-developer/answer/12085295) |
| Pagos y suscripciones | Transporte y suscripción del conductor son conceptos distintos. | Determinar política de cobro y elegibilidad; la central no constituye por sí sola una excepción a Billing. [Pagos](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en) |
| Data safety | Declaración por app, incluidos SDK y servidor. | No declarar “sin datos recopilados”. Verificar cifrado y eliminación antes de marcarlos como garantizados. [Formulario](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) |
| Calidad, funcionalidad, engaño y metadatos | La ficha debe describir funciones realmente disponibles. | Sin calificaciones ficticias, saldos inventados, promesas de emergencia sin atención o “offline” como viajes nuevos sin servidor. Capturas propias, marca RAPIGO, no recursos de YAAPS. [Programa completo](https://support.google.com/googleplay/android-developer/answer/18265346?hl=en) |
| Contenido, audiencia, anuncios y acceso | Completar cuestionarios sin asumir edad ni clasificación. | Confirmar audiencia y ausencia/presencia de anuncios con todos los proveedores; completar rating y credenciales. Si se dirige a niños, evaluar Families adicionalmente. [Preparar revisión](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en) |
| Contenido de usuarios | Fotos de perfil/documentos y mensajes de soporte. | Verificar visibilidad y control de acceso, canal de reporte y atención; no son un feed público pero siguen siendo datos sensibles. Revisar requisitos aplicables en el programa completo. |
| Políticas sin función correspondiente observada | No se identificaron juegos de azar, préstamos, cripto, salud, noticias, VPN, accesibilidad, SMS/registro de llamadas, anuncios ni apps para niños como funcionalidades del producto. | No activar declaraciones de funciones inexistentes; reevaluar al introducir SDK o nuevos servicios. No se propone añadir ambulancias por copiar una captura. |
| Pruebas de cuenta personal | Depende del tipo/fecha de la cuenta aún no informado. | Cuentas personales posteriores a 13/11/2023: prueba cerrada con 12 testers durante 14 días continuos antes de solicitar producción. [Pruebas](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en) |
| Compatibilidad nativa | Flutter, caché de mapas y MapLibre de pasajero contienen componentes nativos. | AGP 8.11.1 observado. Inspeccionar alineación ELF/ZIP del artefacto y ejecutar en entorno 16 KB; la versión de AGP sola no lo garantiza. [16 KB](https://developer.android.com/guide/practices/page-sizes) |

## Inventario inicial para Data safety y privacidad

No son respuestas finales para enviar. Confirmar finalidad, obligatoriedad, retención y excepciones de “compartir” para cada proveedor con la operación real.

| Datos | App | Uso / destinatarios observados |
|---|---|---|
| Nombre, teléfono, correo/dirección cuando se proporcionan, ID de cuenta | Ambas | Cuenta, coordinación, central y soporte. Teléfono para verificación mediante SMS. |
| Ubicación precisa/aproximada y puntos de recogida/destino | Ambas | Mapas y viajes; conductor transmite seguimiento a servidores y pasajero. El pasajero utiliza ubicación en primer plano. |
| Historial, importes, método de pago y valoraciones | Ambas según rol | Coordinación, historial, rendimiento y soporte. Importes registrados no son movimientos de una billetera. |
| Fotos del conductor, licencia y vehículo; datos de licencia/placa | Conductor | Revisión por central; carga a Cloudinary observada. Confirmar privacidad de las URLs, eliminación y subprocesadores. |
| Información/identificador de dispositivo, sesiones y permisos | Ambas | Control de dispositivos y autenticación. Revisar identificador actual: Android `Build.ID` no es identificador único por instalación; evitar enlazar IDs persistentes prohibidos. |
| Reportes y solicitudes de eliminación | Ambas | Central administra atención. Categoría nueva `eliminacion_cuenta`; definir procedimiento y tiempos reales. |
| Plan, importe y vigencia de suscripción | Conductor / central | Registro administrativo. Aún sin procesador de cobro integrado. |
| Solicitudes a mapas, rutas, fuentes e imágenes | Ambas | Inventariar endpoints efectivos, IP y coordenadas transmitidas. Se observan Google Fonts, servicios de mapas/geocodificación/rutas y almacenamiento de imágenes; confirmar configuración de producción. |

## Preparación del AAB

1. Completar una copia privada de `scripts/play-config.example.json` con endpoints HTTPS y URLs públicas reales. No contiene credenciales.
2. Crear `android/key.properties` en cada app con `storeFile`, `storePassword`, `keyAlias`, `keyPassword`; usar claves existentes si corresponde. Estos archivos y los keystores están ignorados por Git.
3. Validar: `./scripts/build-play.ps1 -App driver -ConfigFile <config.json> -ValidateOnly` (repetir con `passenger`).
4. Compilar quitando `-ValidateOnly`. Gradle rechaza bundles sin `PLAY_STORE=true` o sin firma privada. Esto no sube nada a Play.
5. Inspeccionar permisos fusionados, origen de instalación, firma, comunicaciones, tamaño, ABI y 16 KB. Confirmar que “actualizar” no ofrece un APK externo.
6. Subir primero a pruebas internas cuando los bloqueos se hayan resuelto; completar ficha, política, Data safety, acceso, audiencia, rating, FGS/ubicación y declaraciones de pagos que correspondan.

## Pendientes de producto fuera de esta entrega

- Medición fiable de horas conectadas en servidor, zonas de trabajo aplicadas en despacho y bloqueo de nuevas solicitudes por suscripción vencida sin interrumpir viajes activos.
- Verificación individual de documentos, motivo de rechazo y alertas de vencimiento; actualmente se distingue carga de archivos y autorización global.
- Cobros, devoluciones, conciliación y billetera. No se inventaron precios ni procesadores de pago.
- Emergencia/compartir viaje con infraestructura y atención verificables, flotas y referidos.

El objetivo de publicación solo estará completo cuando se cierren también los bloqueos operativos, legales, de consola y de pruebas reales.
