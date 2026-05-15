import { useEffect, useMemo, useState } from 'react'
import Card from '../../components/cards/Card'
import MetricCard from '../../components/dashboard/MetricCard'
import LiveMapSection from '../../components/dashboard/LiveMapSection'
import VehicleStatusCard from '../../components/dashboard/VehicleStatusCard'
import { useCentral } from '../../hooks/useCentral'

export default function LiveMapPage() {
  const central = useCentral()
  const availableDrivers = central.drivers.filter((driver) => driver.is_available).length
  const busyDrivers = central.drivers.filter((driver) => driver.current_trip_id).length
  const disconnectedDrivers = central.drivers.filter((driver) => !driver.is_available && !driver.current_trip_id).length
  const [selectedDriverId, setSelectedDriverId] = useState<string | null>(central.drivers[0]?.id ?? null)

  useEffect(() => {
    if (!selectedDriverId && central.drivers[0]?.id) {
      setSelectedDriverId(central.drivers[0].id)
    }
  }, [central.drivers, selectedDriverId])

  const selectedDriver = useMemo(
    () => central.drivers.find((driver) => driver.id === selectedDriverId) ?? central.drivers[0] ?? null,
    [central.drivers, selectedDriverId],
  )

  return (
    <div className="saas-page-stack saas-map-page">
      <section className="saas-floating-metrics">
        <MetricCard title="Disponibles" value={`${availableDrivers}`} tone="success" icon="🟢" />
        <MetricCard title="En viaje" value={`${busyDrivers}`} tone="warning" icon="🟠" />
        <MetricCard title="Desconectados" value={`${disconnectedDrivers}`} tone="accent" icon="⚫" />
        <MetricCard title="Viajes visibles" value={`${central.trips.length}`} icon="📡" />
      </section>

      <section className="saas-map-layout">
        <div className="saas-map-stage">
          <LiveMapSection
            drivers={central.drivers}
            trips={central.trips}
            offlineStatus={central.offlineMapStatus}
            mapFullscreen={central.mapFullscreen}
            setMapFullscreen={central.setMapFullscreen}
          />
        </div>

        <aside className="saas-map-sidebar">
          <Card title="Flota activa" subtitle="Selecciona una unidad para mas contexto" className="saas-panel-dark">
            <div className="saas-vehicle-list">
              {central.drivers.map((driver) => (
                <VehicleStatusCard
                  key={driver.id}
                  title={`Unidad ${driver.id.slice(0, 8)}`}
                  subtitle={driver.status}
                  status={driver.current_trip_id ? 'En viaje' : driver.is_available ? 'Disponible' : 'Desconectado'}
                  meta={driver.location?.updatedAt ? `GPS ${new Date(driver.location.updatedAt).toLocaleTimeString('es-BO')}` : 'Sin señal reciente'}
                  active={driver.id === selectedDriver?.id}
                  onClick={() => setSelectedDriverId(driver.id)}
                />
              ))}
            </div>
          </Card>

          <Card title="Unidad seleccionada" subtitle="Panel lateral de seguimiento" className="saas-panel-dark">
            {selectedDriver ? (
              <div className="saas-detail-stack">
                <div className="saas-detail-row">
                  <span>ID</span>
                  <strong>{selectedDriver.id}</strong>
                </div>
                <div className="saas-detail-row">
                  <span>Estado</span>
                  <strong>{selectedDriver.status}</strong>
                </div>
                <div className="saas-detail-row">
                  <span>Disponibilidad</span>
                  <strong>{selectedDriver.is_available ? 'Disponible' : 'No disponible'}</strong>
                </div>
                <div className="saas-detail-row">
                  <span>Viaje actual</span>
                  <strong>{selectedDriver.current_trip_id ? selectedDriver.current_trip_id.slice(0, 8) : 'Sin viaje'}</strong>
                </div>
                <div className="saas-detail-row">
                  <span>Ultima lectura</span>
                  <strong>{selectedDriver.location?.updatedAt ? new Date(selectedDriver.location.updatedAt).toLocaleString('es-BO') : 'Sin telemetria'}</strong>
                </div>
              </div>
            ) : (
              <p className="subtitle">No hay conductores visibles todavia.</p>
            )}
          </Card>
        </aside>
      </section>
    </div>
  )
}
