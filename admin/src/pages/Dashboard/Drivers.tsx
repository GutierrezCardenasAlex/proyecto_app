import Card from '../../components/cards/Card'
import MetricCard from '../../components/dashboard/MetricCard'
import { useCentral } from '../../hooks/useCentral'

export default function DriversPage() {
  const central = useCentral()
  const authorized = central.pendingDrivers.filter((driver) => driver.access_status === 'AUTORIZADO').length

  return (
    <div className="saas-page-stack">
      <section className="saas-metric-grid">
        <MetricCard title="Conductores visibles" value={`${central.drivers.length}`} icon="👤" />
        <MetricCard title="Disponibles" value={`${central.drivers.filter((driver) => driver.is_available).length}`} tone="success" icon="🟢" />
        <MetricCard title="En viaje" value={`${central.drivers.filter((driver) => driver.current_trip_id).length}`} tone="warning" icon="🚕" />
        <MetricCard title="Aprobados" value={`${authorized}`} icon="✅" />
      </section>

      <section className="saas-two-column">
        <Card title="Conductores activos" subtitle="Vista ejecutiva de la flota humana" className="saas-panel-dark">
          <div className="list">
            {central.drivers.map((driver) => (
              <article key={driver.id} className="list-card stack-card">
                <div>
                  <strong>Conductor {driver.id.slice(0, 8)}</strong>
                  <p>{driver.status} · {driver.is_available ? 'Disponible' : 'No disponible'}</p>
                </div>
                <span className={driver.current_trip_id ? 'status-pill warning subtle' : driver.is_available ? 'status-pill success subtle' : 'status-pill danger subtle'}>
                  {driver.current_trip_id ? 'En viaje' : driver.is_available ? 'Disponible' : 'Desconectado'}
                </span>
              </article>
            ))}
          </div>
        </Card>

        <Card title="Solicitudes pendientes" subtitle="Acciones rapidas desde central" className="saas-panel-dark">
          <div className="list">
            {central.pendingDrivers.length === 0 && <article className="list-card">No hay conductores pendientes de aprobacion.</article>}
            {central.pendingDrivers.map((driver) => (
              <article key={driver.id} className="list-card stack-card">
                <div>
                  <strong>{driver.full_name || driver.phone}</strong>
                  <p>{driver.phone} · licencia {driver.license_number}</p>
                </div>
                <div className="action-row compact">
                  <button type="button" className="success-button" onClick={() => void central.updateDriverAccess(driver.id, 'AUTORIZADO')}>
                    Aprobar
                  </button>
                  <button type="button" className="danger-button" onClick={() => void central.updateDriverAccess(driver.id, 'RECHAZADO')}>
                    Rechazar
                  </button>
                </div>
              </article>
            ))}
          </div>
        </Card>
      </section>
    </div>
  )
}
