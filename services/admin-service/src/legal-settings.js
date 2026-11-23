const { z } = require('zod');

const defaults = { organization: 'Stellar Labs', developerName: 'axissoft', legalName: '', address: '', email: '', deletionTime: '', retention: '', providers: '', published: false };
const schema = z.object({
  organization: z.string().trim().min(1).max(120),
  developerName: z.string().trim().min(1).max(120),
  legalName: z.string().trim().max(240), address: z.string().trim().max(500),
  email: z.union([z.literal(''), z.string().trim().email().max(254)]),
  deletionTime: z.string().trim().max(1000), retention: z.string().trim().max(6000),
  providers: z.string().trim().max(4000), published: z.boolean(),
}).strict().superRefine((value, ctx) => {
  if (value.published) for (const key of ['legalName', 'address', 'email', 'deletionTime', 'retention', 'providers']) {
    if (!value[key]) ctx.addIssue({ code: 'custom', path: [key], message: 'Completa este dato antes de publicar.' });
  }
});
const escape = value => String(value).replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));

function renderLegal(c, deletion) {
  const title = deletion ? 'Eliminar cuenta y datos' : 'Política de privacidad';
  const contact = `<a href="mailto:${escape(c.email)}">${escape(c.email)}</a>`;
  const content = deletion ? `
    <p>Solicita eliminar tu cuenta de RAPIGO o RAPIGO PRO y los datos personales asociados, incluso si ya desinstalaste la aplicación.</p>
    <h2>Solicitar por correo</h2><p>Escribe a ${contact} con el asunto «Eliminación de cuenta RAPIGO». Indica la aplicación, tu nombre y el teléfono registrado con código de país. No envíes contraseñas, códigos de acceso ni fotos de documentos en el primer mensaje.</p>
    <p>Debes enviar el correo para iniciar la solicitud; esta página no envía mensajes ni confirma su recepción. La central verificará la titularidad y confirmará la atención.</p>
    <h2>Desde la aplicación</h2><p>Perfil / Cuenta → Privacidad y cuenta → Solicitar eliminación. Puedes consultar el avance en Soporte.</p>
    <h2>Plazo de atención</h2><p>${escape(c.deletionTime)}</p>
    <h2>Datos y conservación</h2><p>La solicitud incluye perfil, contacto, documentación e imágenes, ubicaciones, sesiones y datos vinculados a viajes y soporte. Cerrar sesión o bloquear la cuenta no equivale a borrarla.</p>
    <p class="multiline">${escape(c.retention)}</p>` : `
    <p>Esta política comprende RAPIGO (pasajeros) y RAPIGO PRO (conductores), para coordinar viajes en Potosí, Bolivia.</p>
    <h2>Responsable y contacto</h2><p>${escape(c.legalName)} · ${escape(c.address)}. Contacto: ${contact}.</p>
    <h2>Datos y finalidades</h2><ul><li>Nombre, teléfono, identificador de cuenta y correo o dirección cuando se proporcionan: gestionar la cuenta, acceso y coordinación.</li>
    <li>Recogida, destino, conductor, fechas, estado, importes, método de pago registrado y valoraciones: prestar el servicio, historial y soporte.</li>
    <li>Foto del conductor, licencia, placa y datos e imágenes del vehículo: revisión y autorización por la central.</li>
    <li>Datos de dispositivo, sesiones, conexión, reportes y solicitudes: funcionamiento, seguridad y atención.</li>
    <li>Plan, importe y vigencia de suscripción del conductor: gestión administrativa. Un importe registrado no confirma un pago ni implica una billetera.</li></ul>
    <h2>Ubicación y permisos</h2><p>RAPIGO usa ubicación del pasajero en primer plano; también puede seleccionar la recogida manualmente. RAPIGO PRO recopila ubicación del conductor mientras está disponible o en un viaje, incluso cuando la aplicación no está visible, para solicitudes y seguimiento. Puedes gestionar los permisos de ubicación y notificaciones en los ajustes del dispositivo. Las fotos se aportan al registrar o modificar documentación.</p>
    <h2>Destinatarios y proveedores</h2><p>Pasajero y conductor reciben la información necesaria para coordinar el viaje. La central utiliza datos para gestionar cuentas, viajes, documentación y soporte.</p><p class="multiline">${escape(c.providers)}</p>
    <h2>Conservación y eliminación</h2><p class="multiline">${escape(c.retention)}</p><p>Plazo de atención de eliminación: ${escape(c.deletionTime)}. <a href="eliminar-cuenta">Cómo solicitar la eliminación</a>.</p>
    <h2>Consultas, corrección y cambios</h2><p>Para consultar o corregir tus datos, escribe a ${contact} o utiliza Soporte. Las actualizaciones de esta política se publican aquí con su fecha; los nuevos usos que requieran consentimiento deben comunicarse antes de comenzar.</p>`;
  return `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${title} · RAPIGO</title><style>body{font:16px/1.7 system-ui,sans-serif;color:#172b40;background:#f6f8fb;max-width:760px;margin:auto;padding:24px}a{color:#075a85}h1{line-height:1.2}h2{font-size:1.2rem;margin-top:28px}nav{display:flex;gap:24px;flex-wrap:wrap}header,footer{padding:20px 0}footer{border-top:1px solid #cdd5df}.multiline{white-space:pre-wrap}p,a{overflow-wrap:anywhere}</style></head><body><header><strong>RAPIGO / PRO · ${escape(c.organization)}</strong><nav><a href="privacidad">Privacidad</a><a href="eliminar-cuenta">Eliminar cuenta</a></nav></header><main><h1>${title}</h1>${content}</main><footer>Marca: ${escape(c.organization)} · Programador en Google Play: ${escape(c.developerName)}<br>Actualizado: ${escape(c.updatedAt)}</footer></body></html>`;
}

function registerLegalSettings(app, { pool, ensureAdmin }) {
  async function read() {
    const result = await pool.query("SELECT value, updated_at FROM app_settings WHERE key = 'legal_settings'");
    const row = result.rows[0];
    return { ...defaults, ...(row ? schema.parse(JSON.parse(row.value)) : {}), updatedAt: row?.updated_at ?? null };
  }
  app.get('/settings/legal', { preHandler: ensureAdmin }, read);
  app.put('/settings/legal', { preHandler: ensureAdmin }, async (request, reply) => {
    const parsed = schema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ message: 'Revisa los datos legales.', issues: parsed.error.issues });
    await pool.query(`INSERT INTO app_settings (key, value, updated_at) VALUES ('legal_settings', $1, NOW())
      ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()`, [JSON.stringify(parsed.data)]);
    return read();
  });
  for (const path of ['config', 'privacidad', 'eliminar-cuenta']) {
    app.get(`/public/legal/${path}`, async (_request, reply) => {
      reply.header('Cache-Control', 'no-store');
      const config = await read();
      if (!config.published) return reply.code(503).send({ message: 'Información legal aún no publicada.' });
      if (path === 'config') return config;
      reply.header('X-Content-Type-Options', 'nosniff');
      reply.header('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'");
      return reply.type('text/html; charset=utf-8').send(renderLegal(config, path === 'eliminar-cuenta'));
    });
  }
}
module.exports = { registerLegalSettings, renderLegal, schema };
