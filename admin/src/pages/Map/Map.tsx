import Card from '../../components/cards/Card'
import ExecutiveStrip from '../../components/dashboard/ExecutiveStrip'
import LiveMapSection from '../../components/dashboard/LiveMapSection'
import PageHero from '../../components/dashboard/PageHero'
import { useCentral } from '../../hooks/useCentral'
import { VIEW_DESCRIPTIONS, VIEW_LABELS } from '../../utils/constants'

export default function MapPage() {
  const central = useCentral()

  return (
    <>
      <PageHero
        eyebrow="Central Flash Go / Potosi"
        title={VIEW_LABELS.map}
        description={VIEW_DESCRIPTIONS.map}
        metrics={[
          { label: 'Disponibles', value: `${central.drivers.filter((driver) => driver.is_available).length}` },
          { label: 'En ruta', value: `${central.drivers.filter((driver) => driver.current_trip_id).length}` },
          { label: 'Viajes', value: `${central.trips.length}` },
          { label: 'Cobertura', value: '15 km' },
        ]}
      />
      <ExecutiveStrip
        title="Pulso de flota"
        subtitle="Lectura instantanea de cobertura y disponibilidad"
        signals={central.executiveSignals}
      />
      <LiveMapSection
        drivers={central.drivers}
        trips={central.trips}
        offlineStatus={central.offlineMapStatus}
        mapFullscreen={central.mapFullscreen}
        setMapFullscreen={central.setMapFullscreen}
      />
      <section className="content-grid dashboard-gap">
        <div className="triple-grid">
          <Card title="Flota visible" subtitle={`${central.drivers.length} conductores`}>
            <div className="list">
              {central.drivers.slice(0, 8).map((driver) => (
                <article key={driver.id} className="list-card">
                  <div>
                    <strong>Conductor {driver.id.slice(0, 8)}</strong>
                    <p>{driver.status}</p>
                  </div>
                  <span className={driver.is_available ? 'status-pill success subtle' : 'status-pill warning subtle'}>
                    {driver.is_available ? 'Disponible' : 'No disponible'}
                  </span>
                </article>
              ))}
            </div>
          </Card>
          <Card title="Viajes visibles" subtitle={`${central.trips.length} en pantalla`}>
            <div className="list">
              {central.trips.slice(0, 8).map((trip) => (
                <article key={trip.id} className="list-card">
                  <div>
                    <strong>{trip.id.slice(0, 8)}</strong>
                    <p>{trip.status}</p>
                  </div>
                  <span>{trip.driver_id ? 'Asignado' : 'Buscando'}</span>
                </article>
              ))}
            </div>
          </Card>
          <Card title="Infraestructura" subtitle="Lectura rapida">
            <div className="mini-stats-grid">
              <div className="mini-stat-card">
                <span>Offline</span>
                <strong>{central.offlineMapStatus.status}</strong>
              </div>
              <div className="mini-stat-card">
                <span>Fuente</span>
                <strong>{central.offlineMapStatus.sourceType}</strong>
              </div>
            </div>
          </Card>
        </div>
      </section>
    </>
  )
}
