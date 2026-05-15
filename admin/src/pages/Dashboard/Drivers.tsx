import Card from '../../components/cards/Card'
import MetricCard from '../../components/dashboard/MetricCard'
import { useCentral } from '../../hooks/useCentral'
import { getDriverAvailabilityLabel, getDriverDisplayName, getDriverStatusLabel, getDriverTelemetryDate } from '../../utils/helpers'

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
                  <strong>{getDriverDisplayName(driver)}</strong>
                  <p>{driver.phone || driver.id} · {getDriverStatusLabel(driver)} · {getDriverAvailabilityLabel(driver)}</p>
                </div>
                <span
                  className={
                    getDriverStatusLabel(driver) === 'En viaje'
                      ? 'status-pill warning subtle'
                      : getDriverStatusLabel(driver) === 'Disponible'
                        ? 'status-pill success subtle'
                        : 'status-pill danger subtle'
                  }
                >
                  {getDriverTelemetryDate(driver) ? getDriverStatusLabel(driver) : 'Sin telemetria · offline'}
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
