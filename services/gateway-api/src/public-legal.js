const paths = new Set(['config', 'privacidad', 'eliminar-cuenta'].map(name => `/api/admin/public/legal/${name}`));
function isPublicLegalRequest(request) {
  return (request.method === 'GET' || request.method === 'HEAD') && paths.has(request.url.split('?')[0]);
}
module.exports = { isPublicLegalRequest };
