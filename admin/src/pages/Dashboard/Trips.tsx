import Card from '../../components/cards/Card'
import MetricCard from '../../components/dashboard/MetricCard'
import { useCentral } from '../../hooks/useCentral'

export default function TripsPage() {
  const central = useCentral()

  return (
    <div className="saas-page-stack">
      <section className="saas-metric-grid">
        <MetricCard title="Viajes visibles" value={`${central.trips.length}`} icon="🛣️" />
        <MetricCard title="Asignados" value={`${central.trips.filter((trip) => trip.driver_id).length}`} tone="success" icon="📌" />
        <MetricCard title="Pendientes" value={`${central.trips.filter((trip) => !trip.driver_id).length}`} tone="warning" icon="🟠" />
        <MetricCard title="Autos en ruta" value={`${central.drivers.filter((driver) => driver.current_trip_id).length}`} icon="🚦" />
      </section>

      <Card title="Viajes en seguimiento" subtitle="Operacion activa y respuesta rapida" className="saas-panel-dark">
        <div className="list">
          {central.trips.length === 0 && <article className="list-card">No hay viajes visibles en este momento.</article>}
          {central.trips.map((trip) => (
            <article key={trip.id} className="list-card stack-card">
              <div>
                <strong>Viaje {trip.id.slice(0, 8)}</strong>
                <p>{trip.status} · {trip.driver_id ? `chofer ${trip.driver_id.slice(0, 8)}` : 'sin conductor asignado'}</p>
              </div>
              <span className={trip.driver_id ? 'status-pill success subtle' : 'status-pill warning subtle'}>
                {trip.driver_id ? 'Asignado' : 'Pendiente'}
              </span>
            </article>
          ))}
        </div>
      </Card>
    </div>
  )
}
