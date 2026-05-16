import { useEffect, useMemo, useState } from 'react'
import Card from '../../components/cards/Card'
import MetricCard from '../../components/dashboard/MetricCard'
import LiveMapSection from '../../components/dashboard/LiveMapSection'
import VehicleStatusCard from '../../components/dashboard/VehicleStatusCard'
import { useCentral } from '../../hooks/useCentral'
import {
  getDriverAvailabilityLabel,
  getDriverDisplayName,
  getDriverStateValue,
  getDriverStatusLabel,
  getDriverTelemetryDateTimeLabel,
  getDriverTelemetryLabel,
} from '../../utils/helpers'

export default function MonitoringMapPage() {
  const central = useCentral()
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
    <div className="saas-page-stack monitor-page-stack">
      <section className="saas-floating-metrics">
        <MetricCard title="Conductores visibles" value={`${central.drivers.length}`} icon="📡" />
        <MetricCard title="Disponibles" value={`${central.drivers.filter((driver) => getDriverStatusLabel(driver) === 'Disponible').length}`} tone="success" icon="🟢" />
        <MetricCard title="En viaje" value={`${central.drivers.filter((driver) => getDriverStatusLabel(driver) === 'En viaje').length}`} tone="warning" icon="🚕" />
        <MetricCard title="Offline" value={`${central.drivers.filter((driver) => getDriverStatusLabel(driver) === 'Desconectado').length}`} icon="⚫" />
      </section>

      <section className="saas-map-layout monitor-map-layout">
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
          <Card title="Mapa en vivo" subtitle="Monitoreo restringido de flota" className="saas-panel-dark">
            <div className="saas-vehicle-list">
              {central.drivers.map((driver) => (
                <VehicleStatusCard
                  key={driver.id}
                  title={getDriverDisplayName(driver)}
                  subtitle={driver.phone || driver.id}
                  status={getDriverStatusLabel(driver)}
                  meta={getDriverTelemetryLabel(driver)}
                  active={driver.id === selectedDriver?.id}
                  onClick={() => setSelectedDriverId(driver.id)}
                />
              ))}
            </div>
          </Card>

          <Card title="Unidad seleccionada" subtitle="Solo lectura operativa" className="saas-panel-dark">
            {selectedDriver ? (
              <div className="saas-detail-stack">
                <div className="saas-detail-row">
                  <span>Conductor</span>
                  <strong>{getDriverDisplayName(selectedDriver)}</strong>
                </div>
                <div className="saas-detail-row">
                  <span>Contacto</span>
                  <strong>{selectedDriver.phone || selectedDriver.id}</strong>
                </div>
                <div className="saas-detail-row">
                  <span>Estado</span>
                  <strong>{getDriverStateValue(selectedDriver)}</strong>
                </div>
                <div className="saas-detail-row">
                  <span>Disponibilidad</span>
                  <strong>{getDriverAvailabilityLabel(selectedDriver)}</strong>
                </div>
                <div className="saas-detail-row">
                  <span>Viaje actual</span>
                  <strong>{selectedDriver.current_trip_id ? selectedDriver.current_trip_id.slice(0, 8) : 'Sin viaje'}</strong>
                </div>
                <div className="saas-detail-row">
                  <span>Ultima lectura</span>
                  <strong>{getDriverTelemetryDateTimeLabel(selectedDriver)}</strong>
                </div>
              </div>
            ) : (
              <p className="subtitle">No hay unidades disponibles para mostrar.</p>
            )}
          </Card>
        </aside>
      </section>
    </div>
  )
}
