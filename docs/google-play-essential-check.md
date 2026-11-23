# Google Play: revisión esencial · 23/11/2026

**Resultado: todavía no enviar a producción.** Revisión focalizada en RAPIGO PRO; las páginas legales también contemplan RAPIGO pasajero. No se revisó código archivo por archivo, no se accedió a Play Console y no se verificó el servidor desplegado.

## Confirmado en el repositorio

- Conductor: API objetivo mínima 36; bundle exige `PLAY_STORE=true`, HTTPS, enlaces legales HTTPS y firma privada.
- La edición Play elimina `REQUEST_INSTALL_PACKAGES` y el proveedor del instalador; el actualizador Dart comprueba `PLAY_STORE`. Pendiente comprobar el manifiesto fusionado del AAB final.
- Hay aviso de ubicación en segundo plano antes de permisos y acceso desde la app a privacidad y solicitud de eliminación.
- La solicitud interna se envía a soporte: **no borra por sí sola**.
- No existe `android/key.properties` en ninguna de las dos apps. No se inspeccionaron secretos ni se generaron claves.
- `services/admin-service/src/index.js`, endpoint `DELETE /users/:userId`: responde 409 si existen viajes. Este bloqueo impide considerar resuelta la eliminación de cuentas y sus datos.

## Lo mínimo pendiente para enviar

1. Completar y publicar las páginas legales con correo atendido, identidad, proveedores, plazos y retención reales. Deben ser públicas, sin inicio de sesión. Configurar sus URLs en las apps y Play Console.
2. Resolver y verificar un procedimiento de eliminación/anominización, incluyendo cuentas con viajes, imágenes, ubicación, sesiones y proveedores. No se han ejecutado borrados ni migraciones.
3. Configurar clave de carga y endpoints reales HTTPS/WSS; generar AAB firmado cuando se cierre lo anterior. Verificar permisos finales, firma y compatibilidad de bibliotecas nativas con páginas de 16 KB.
4. En Play Console: Data safety por app, ubicación en segundo plano/servicio de ubicación, acceso de revisores, audiencia, clasificación de contenido, anuncios y ficha/capturas reales. Resolver si el cobro de suscripción digital necesita Play Billing antes de ofrecer compras; el transporte físico es otro concepto.
5. Una comprobación funcional breve: registro/acceso, permiso denegado, viaje conductor-pasajero, reconexión y recepción/atención de una solicitud de eliminación. No se exige aquí una suite completa.

El propietario confirmó cuenta Play **personal**, nombre de programador **axissoft** y marca **Stellar Labs**. La fecha de creación y el acceso actual a producción siguen sin comprobarse. Las cuentas personales creadas después del 13/11/2023 requieren 12 testers durante 14 días continuos antes de solicitar acceso a producción. No es una prueba que se pueda sustituir por tests locales. El ID y correo privado de la cuenta Play no se publican automáticamente como contacto de usuarios.

## Datos editables desde la central

Se añadió Configuración → Privacidad y contacto. Permite editar marca, nombre del programador, responsable, domicilio, correo público, proveedores, conservación y plazo de eliminación. Guarda en la tabla existente `app_settings`; no requiere migraciones. Solo administradores pueden leer el borrador o modificarlo. La publicación requiere completar los datos; la interfaz pide confirmar su veracidad operativa.

Al desplegar central, admin-service y gateway-api, los enlaces permanentes serán:

- `<ORIGEN_HTTPS>/api/admin/public/legal/privacidad`
- `<ORIGEN_HTTPS>/api/admin/public/legal/eliminar-cuenta`

Estas páginas se generan con los datos vigentes de la central y se abren sin cuenta. Solo esas rutas de lectura y `/config` se excluyen de autenticación del gateway. Los campos se escapan para impedir inyección HTML. Un borrador devuelve 503 y no expone sus datos. La API no recibe solicitudes de eliminación web: ofrece el correo publicado, al que el usuario debe enviar la solicitud.

Ambas apps consultan la configuración publicada al abrir Privacidad y cuenta y muestran marca, correo y enlaces actualizados. Si no hay conexión conservan los enlaces incluidos en la compilación. Hace falta una actualización inicial de las apps para incorporar este comportamiento; los cambios posteriores de contacto no requieren recompilarlas.

El sitio privado de Sites continúa como maqueta estática; no se sincroniza con la central. Para Google Play se usarán las páginas dinámicas del servidor HTTPS de producción, una vez desplegadas y publicadas desde la central. Configurar también esas URLs en `PRIVACY_POLICY_URL` y `ACCOUNT_DELETION_URL` para el respaldo sin conexión a configuración. No se han desplegado estos servicios ni habilitado una política definitiva.

## Sitio creado

`sites/rapigo-legal/`: generador `build.mjs`, datos `legal-config.json`, instrucciones `README.md` y tres páginas en `dist/`: contacto/inicio, `privacidad.html` y `eliminar-cuenta.html`.

El borrador está marcado explícitamente y la eliminación externa no aparenta recibir solicitudes cuando falta el correo. Al configurar un correo válido, ofrece un mensaje preparado que el usuario debe enviar. Confirmar recepción antes de considerarlo funcional. No sustituye el borrado real.

No se añadieron términos de cobro inventados. La política de privacidad y el recurso de eliminación son los enlaces necesarios identificados; condiciones de servicio/pago deberán describir la operación real cuando se defina.

## Comprobaciones realizadas

- Lectura dirigida de Gradle, manifiestos Play/principal, aviso de ubicación, privacidad y endpoint administrativo de eliminación.
- `node build.mjs` y `node --check build.mjs`: correctos.
- Tres HTML generados y enlaces locales: correctos. Privacidad y eliminación respondieron HTTP 200 en vista local.
- No se hicieron builds Android, suites Flutter, pruebas de servidor ni validación visual en dispositivo: se limitó el trabajo al alcance esencial solicitado. Tampoco se afirma aprobación de Google Play.

Verificación adicional de la configuración legal: dos pruebas Node con Fastify y almacenamiento simulado (autorización, borrador no público, campos obligatorios, escape HTML, actualización del correo y despublicación), sintaxis de servicios/gateway, TypeScript de la central sin emitir archivos y análisis Dart focalizado de las dos pantallas de privacidad. Todo correcto. No se ejecutó el servidor contra una base de datos real, ni se probó envío de correo o recepción de solicitudes.

## Fuentes oficiales consultadas

- [API objetivo](https://support.google.com/googleplay/android-developer/answer/11926878): API 36 para nuevas apps y actualizaciones de teléfono.
- [Datos de usuarios y privacidad](https://support.google.com/googleplay/android-developer/answer/10144311).
- [Eliminación de cuentas](https://support.google.com/googleplay/android-developer/answer/13327111): vía interna y recurso externo, datos asociados y retención informada.
- [Pruebas de cuentas personales](https://support.google.com/googleplay/android-developer/answer/14151465).

La auditoría extensa anterior sigue disponible en `docs/google-play-readiness.md`; esta nota resume los bloqueos que impiden enviar ahora.
