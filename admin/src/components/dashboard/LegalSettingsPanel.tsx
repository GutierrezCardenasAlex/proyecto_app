import { useEffect, useState } from 'react'
import Card from '../cards/Card'
import { useAuth } from '../../hooks/useAuth'
import { API_BASE } from '../../utils/constants'
import { apiRequest } from '../../services/api'

const initial = { organization: 'Stellar Labs', developerName: 'axissoft', legalName: '', address: '', email: '', deletionTime: '', retention: '', providers: '', published: false }
type Settings = typeof initial
const fields: [Exclude<keyof Settings, 'published'>, string][] = [
  ['organization', 'Marca pública'], ['developerName', 'Nombre del programador en Google Play'],
  ['legalName', 'Persona o entidad responsable'], ['address', 'Domicilio del responsable'],
  ['email', 'Correo público de privacidad y eliminación'], ['deletionTime', 'Plazo real de respuesta y eliminación'],
  ['retention', 'Datos eliminados, anonimizados y conservados: plazos y motivos por categoría'],
  ['providers', 'Proveedores activos: datos recibidos, finalidad, países y transferencias'],
]

export default function LegalSettingsPanel() {
  const { token } = useAuth()
  const [draft, setDraft] = useState<Settings>(initial)
  const [loaded, setLoaded] = useState(false)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [confirmed, setConfirmed] = useState(false)
  useEffect(() => {
    let active = true
    setLoaded(false)
    apiRequest<Settings>(`${API_BASE}/admin/settings/legal`, { headers: { Authorization: `Bearer ${token}` } })
      .then(data => { if (active) { setDraft(Object.fromEntries(Object.keys(initial).map(key => [key, data[key as keyof Settings]])) as Settings); setLoaded(true) } })
      .catch((error: Error) => { if (active) setMessage(error.message) })
    return () => { active = false }
  }, [token])
  async function save() {
    setBusy(true); setMessage('')
    try {
      await apiRequest(`${API_BASE}/admin/settings/legal`, {
        method: 'PUT', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(draft),
      })
      setConfirmed(false)
      setMessage(draft.published ? 'Datos publicados. Las páginas y las apps los mostrarán al abrirse de nuevo.' : 'Borrador guardado. Las páginas públicas están deshabilitadas.')
    } catch (error) { setMessage(error instanceof Error ? error.message : 'No se pudo guardar.') }
    finally { setBusy(false) }
  }
  return <Card title="Privacidad y contacto" subtitle="Stellar Labs es la marca; el nombre del programador debe coincidir con Google Play. Estos campos serán públicos al publicar." className="saas-panel-dark">
    <form className="settings-stack" onSubmit={event => { event.preventDefault(); void save() }}>
      <fieldset disabled={!loaded || busy} className="settings-stack">
        {fields.map(([key, label]) => <label className="admin-field" key={key}><span>{label}</span>
          {['retention', 'providers', 'deletionTime'].includes(key)
            ? <textarea rows={4} required={draft.published} maxLength={key === 'retention' ? 6000 : key === 'providers' ? 4000 : 1000} value={draft[key]} onChange={event => { setDraft({ ...draft, [key]: event.target.value }); setConfirmed(false) }} />
            : <input type={key === 'email' ? 'email' : 'text'} required={draft.published || key === 'organization' || key === 'developerName'} maxLength={key === 'address' ? 500 : key === 'email' ? 254 : key === 'legalName' ? 240 : 120} value={draft[key]} onChange={event => { setDraft({ ...draft, [key]: event.target.value }); setConfirmed(false) }} />}
        </label>)}
        <label><input type="checkbox" checked={draft.published} onChange={event => { setDraft({ ...draft, published: event.target.checked }); setConfirmed(false) }} /> Publicar datos legales</label>
        <p>Al desmarcar publicación se deshabilitan también las páginas que hayas enlazado en Play. No publiques hasta poder atender el correo y ejecutar la eliminación real, incluidas cuentas con viajes.</p>
        {draft.published && <label><input type="checkbox" required checked={confirmed} onChange={event => setConfirmed(event.target.checked)} /> Confirmo que el contacto, los proveedores y las prácticas de conservación y eliminación descritas son reales.</label>}
        <button type="submit" disabled={busy || !loaded || (draft.published && !confirmed)}>{busy ? 'Guardando…' : draft.published ? 'Guardar y publicar' : 'Guardar borrador'}</button>
      </fieldset>
    </form>
    {message && <p role="status">{message}</p>}
    <p>Enlaces permanentes (requieren el servidor de producción HTTPS):</p>
    <ul><li><a href={`${API_BASE}/admin/public/legal/privacidad`} target="_blank" rel="noreferrer">Política de privacidad</a></li><li><a href={`${API_BASE}/admin/public/legal/eliminar-cuenta`} target="_blank" rel="noreferrer">Eliminación de cuenta</a></li></ul>
  </Card>
}
