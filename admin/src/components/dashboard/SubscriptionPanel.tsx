import { useCallback, useEffect, useState } from 'react'
import Card from '../cards/Card'
import { useAuth } from '../../hooks/useAuth'
import { API_BASE } from '../../utils/constants'
import { apiRequest } from '../../services/api'

type Plan = { code: string; name: string; amount: string; duration_days: number; enabled: boolean }
type Driver = { id: string; full_name: string; phone: string }
type Grant = { id: string; plan_name: string; full_name: string; expires_at: string; reference: string }

export default function SubscriptionPanel() {
  const { token } = useAuth()
  const [plans, setPlans] = useState<Plan[]>([])
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [grants, setGrants] = useState<Grant[]>([])
  const [draft, setDraft] = useState({ code: '', name: '', amount: '', durationDays: '', enabled: false })
  const [driverId, setDriverId] = useState('')
  const [planCode, setPlanCode] = useState('')
  const [reference, setReference] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const request = useCallback(<T,>(path: string, method = 'GET', body?: unknown) =>
    apiRequest<T>(`${API_BASE}/admin/subscriptions/${path}`, {
      method, headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    }), [token])
  const load = useCallback(async () => {
    const [nextPlans, nextDrivers, nextGrants] = await Promise.all([
      request<Plan[]>('plans'), request<Driver[]>('drivers'), request<Grant[]>('grants'),
    ])
    setPlans(nextPlans); setDrivers(nextDrivers); setGrants(nextGrants)
  }, [request])
  useEffect(() => { void load().catch((error: Error) => setMessage(error.message)) }, [load])
  async function save(grant: boolean) {
    setBusy(true); setMessage('')
    try {
      if (grant) {
        await request('grants', 'POST', { driverId, planCode, reference })
        setReference('')
      } else {
        await request('plans', 'PUT', { ...draft, amount: Number(draft.amount), durationDays: Number(draft.durationDays) })
      }
      setMessage(grant ? 'Vigencia registrada. No se realizó ningún cobro automático.' : 'Plan guardado.')
      await load()
    } catch (error) { setMessage(error instanceof Error ? error.message : 'No se pudo guardar.') }
    finally { setBusy(false) }
  }
  return <Card title="Suscripciones de conductores" subtitle="Planes y vigencias administrados por Stellar Labs. Los cambios de precio no alteran autorizaciones existentes." className="saas-panel-dark">
    <form className="settings-stack" onSubmit={(event) => { event.preventDefault(); void save(false) }}>
      <label>Plan existente<select value={draft.code} onChange={(event) => {
        const plan = plans.find((item) => item.code === event.target.value)
        setDraft(plan ? { code: plan.code, name: plan.name, amount: String(plan.amount), durationDays: String(plan.duration_days), enabled: plan.enabled } : { code: '', name: '', amount: '', durationDays: '', enabled: false })
      }}><option value="">Crear plan</option>{plans.map((plan) => <option key={plan.code} value={plan.code}>{plan.name}</option>)}</select></label>
      <label>Código<input required pattern="[a-z0-9_-]{2,40}" value={draft.code} onChange={(event) => setDraft({ ...draft, code: event.target.value })} /></label>
      <label>Nombre<input required minLength={2} maxLength={80} value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></label>
      <label>Precio en Bs<input required type="number" min="0" max="100000" step="0.01" value={draft.amount} onChange={(event) => setDraft({ ...draft, amount: event.target.value })} /></label>
      <label>Duración en días<input required type="number" min="1" max="365" step="1" value={draft.durationDays} onChange={(event) => setDraft({ ...draft, durationDays: event.target.value })} /></label>
      <label><input type="checkbox" checked={draft.enabled} onChange={(event) => setDraft({ ...draft, enabled: event.target.checked })} /> Plan activo</label>
      <button type="submit" disabled={busy}>Guardar plan</button>
    </form>
    <form className="settings-stack" onSubmit={(event) => { event.preventDefault(); void save(true) }}>
      <h3>Registrar vigencia</h3>
      <p>Usa esta acción después de verificar la autorización correspondiente. Una renovación se añade al final de la vigencia existente.</p>
      <label>Conductor<select required value={driverId} onChange={(event) => setDriverId(event.target.value)}><option value="">Seleccionar</option>{drivers.map((driver) => <option key={driver.id} value={driver.id}>{driver.full_name} · {driver.phone}</option>)}</select></label>
      <label>Plan<select required value={planCode} onChange={(event) => setPlanCode(event.target.value)}><option value="">Seleccionar</option>{plans.filter((plan) => plan.enabled).map((plan) => <option key={plan.code} value={plan.code}>{plan.name} · Bs {plan.amount} · {plan.duration_days} días</option>)}</select></label>
      <label>Referencia única<input required minLength={4} maxLength={120} value={reference} onChange={(event) => setReference(event.target.value)} /></label>
      <button type="submit" disabled={busy}>Registrar vigencia</button>
    </form>
    {message && <p role="status">{message}</p>}
    <h3>Últimas autorizaciones</h3>
    {grants.length === 0 && <p>No hay autorizaciones registradas.</p>}
    {grants.map((grant) => <article key={grant.id} className="list-card"><strong>{grant.full_name} · {grant.plan_name}</strong><p>Vence {new Date(grant.expires_at).toLocaleString('es-BO')} · {grant.reference}</p></article>)}
  </Card>
}
