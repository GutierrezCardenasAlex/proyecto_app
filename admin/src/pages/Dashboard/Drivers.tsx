import Card from '../../components/cards/Card'
import StatCard from '../../components/dashboard/StatCard'
import { useCentral } from '../../hooks/useCentral'
import { formatDateTime, getDriverAvailabilityLabel, getDriverDisplayName, getDriverStatusLabel, getDriverTelemetryDate } from '../../utils/helpers'

export default function DriversPage() {
  const central = useCentral()
  const authorized = central.pendingDrivers.filter((driver) => driver.access_status === 'AUTORIZADO').length
  const deliveryAvailable = central.deliveryDrivers.filter((driver) => driver.is_available).length

  return (
    <div className="saas-page-stack">
      <section className="admin-section-headline">
        <div>
          <span className="eyebrow">Flota humana</span>
          <h2>Conductores, aprobaciones y disponibilidad</h2>
          <p>Lectura operativa directa para revisar choferes conectados, estados de viaje y aprobaciones pendientes desde una sola cabina.</p>
        </div>
      </section>

      <section className="admin-stats-grid">
        <StatCard label="Conductores visibles" value={`${central.drivers.length}`} detail="Flota humana reportando al panel" icon="👤" />
        <StatCard label="Disponibles" value={`${central.drivers.filter((driver) => driver.is_available).length}`} detail="Listos para operar" icon="🟢" tone="success" />
        <StatCard label="En viaje" value={`${central.drivers.filter((driver) => driver.current_trip_id).length}`} detail="Unidades actualmente en ruta" icon="🚕" tone="warning" />
        <StatCard label="Aprobados" value={`${authorized}`} detail={`${central.pendingDrivers.length} pendientes de revisar`} icon="✅" tone="neutral" />
        <StatCard label="Delivery activo" value={`${central.deliveryDrivers.length}`} detail={`${deliveryAvailable} disponibles ahora`} icon="📦" tone="success" />
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

        <Card title="Delivery activo" subtitle="Conductores que activaron el servicio extra" className="saas-panel-dark">
          <div className="list">
            {central.deliveryDrivers.length === 0 && <article className="list-card">Ningun conductor activo delivery todavia.</article>}
            {central.deliveryDrivers.map((driver) => (
              <article key={driver.id} className="list-card stack-card">
                <div>
                  <strong>{driver.full_name || driver.phone || driver.id}</strong>
                  <p>{driver.phone || 'sin telefono'} · {driver.is_available ? 'Disponible' : 'No disponible'} · {driver.status}</p>
                  <p>
                    Transporte fijo activo · Delivery extra activo
                  </p>
                  <p>{[driver.vehicle_type, driver.brand, driver.model, driver.color, driver.plate].filter(Boolean).join(' ') || 'vehiculo sin detalle'}</p>
                </div>
                <span className={driver.is_available ? 'status-pill success subtle' : 'status-pill warning subtle'}>
                  Delivery
                </span>
              </article>
            ))}
          </div>
        </Card>
      </section>

      <section className="saas-two-column">
        <Card title="Solicitudes pendientes" subtitle="Acciones rapidas desde central" className="saas-panel-dark">
          <div className="list">
            {central.pendingDrivers.length === 0 && <article className="list-card">No hay conductores pendientes de aprobacion.</article>}
            {central.pendingDrivers.map((driver) => (
              <article key={driver.id} className="list-card stack-card">
                <div>
                  <strong>{driver.full_name || driver.phone}</strong>
                  <p>{driver.phone} · {driver.address || 'sin direccion'}</p>
                  <p>Registrado: {formatDateTime(driver.created_at)} · Actualizado: {formatDateTime(driver.updated_at)}</p>
                  <p>
                    Licencia {driver.license_number || 'pendiente'} · Categoria {driver.license_category || 'sin categoria'} · Emision{' '}
                    {driver.license_issue_date || 'pendiente'} · Vence {driver.license_expiry_date || 'pendiente'}
                  </p>
                  <p>Placa {driver.plate || 'sin placa'}</p>
                  <p>{[driver.vehicle_type, driver.brand, driver.model, driver.color, driver.year].filter(Boolean).join(' ') || 'vehiculo incompleto'}</p>
                  {driver.missing_fields?.length ? (
                    <p className="muted-text">Falta verificar: {driver.missing_fields.join(', ')}</p>
                  ) : (
                    <p className="success-text">Expediente completo.</p>
                  )}
                </div>
                <div className="action-row compact">
                  <button type="button" className="success-button" disabled={driver.verification_ready === false} onClick={() => void central.updateDriverAccess(driver.id, 'AUTORIZADO')}>
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
