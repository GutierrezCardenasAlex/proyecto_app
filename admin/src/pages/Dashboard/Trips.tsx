import Card from '../../components/cards/Card'
import StatCard from '../../components/dashboard/StatCard'
import { useCentral } from '../../hooks/useCentral'

export default function TripsPage() {
  const central = useCentral()

  return (
    <div className="saas-page-stack">
      <section className="admin-section-headline">
        <div>
          <span className="eyebrow">Operacion activa</span>
          <h2>Viajes en seguimiento y asignacion</h2>
          <p>Seguimiento claro de los viajes visibles, las asignaciones activas y las unidades que todavia estan esperando conductor.</p>
        </div>
      </section>

      <section className="admin-stats-grid">
        <StatCard label="Viajes visibles" value={`${central.trips.length}`} detail="Servicio mostrado en tiempo real" icon="🛣️" />
        <StatCard label="Asignados" value={`${central.trips.filter((trip) => trip.driver_id).length}`} detail="Conductor vinculado actualmente" icon="📌" tone="success" />
        <StatCard label="Pendientes" value={`${central.trips.filter((trip) => !trip.driver_id).length}`} detail="Esperando asignacion" icon="🟠" tone="warning" />
        <StatCard label="Autos en ruta" value={`${central.drivers.filter((driver) => driver.current_trip_id).length}`} detail="Conductores ya ocupados" icon="🚦" tone="neutral" />
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
