import { useState } from 'react'
import Card from '../../components/cards/Card'
import ActivityPanel from '../../components/dashboard/ActivityPanel'
import MetricCard from '../../components/dashboard/MetricCard'
import OverviewSections from '../../components/dashboard/OverviewSections'
import StatCard from '../../components/dashboard/StatCard'
import VehicleStatusCard from '../../components/dashboard/VehicleStatusCard'
import Modal from '../../components/common/Modal'
import { useCentral } from '../../hooks/useCentral'
import { getDriverAvailabilityLabel, getDriverDisplayName, getDriverStateValue, getDriverStatusLabel, getDriverTelemetryDateTimeLabel, getDriverTelemetryLabel } from '../../utils/helpers'

export default function DashboardHome() {
  const central = useCentral()
  const activeDrivers = central.drivers.filter((driver) => driver.is_available)
  const revenue = Number(central.dashboard.revenue || 0).toFixed(2)
  const [selectedDriverId, setSelectedDriverId] = useState<string | null>(null)
  const selectedDriver = central.drivers.find((driver) => driver.id === selectedDriverId) ?? null

  return (
    <div className="saas-page-stack">
      <section className="saas-hero">
        <div className="saas-hero-copy">
          <span className="eyebrow">Flash Go Fleet Command</span>
          <h1>Panel SaaS de movilidad para monitorear flota, usuarios y servicio en una sola experiencia.</h1>
          <p>La central consolida viajes, conductores, ingresos, soporte y visibilidad operativa con una lectura ejecutiva y moderna.</p>
        </div>
        <div className="saas-hero-metrics">
          <MetricCard title="Autos activos" value={`${central.drivers.length}`} change={`${activeDrivers.length} disponibles ahora`} icon="🚕" />
          <MetricCard title="Viajes del dia" value={`${central.dashboard.activeTrips}`} change={`${central.trips.length} visibles`} tone="warning" icon="📍" />
          <MetricCard title="Conductores conectados" value={`${activeDrivers.length}`} change={`${central.pendingDrivers.length} pendientes`} tone="success" icon="🟢" />
          <MetricCard title="Ingresos estimados" value={`Bs ${revenue}`} change="Actualizado desde central" icon="💸" />
        </div>
      </section>

      <section className="saas-two-column">
        <Card title="Estado general del sistema" subtitle="Indicadores premium de salud operativa" className="saas-panel-dark">
          <div className="saas-health-grid">
            {central.executiveSignals.map((signal) => (
              <StatCard key={signal.label} label={signal.label} value={signal.value} tone={signal.tone === 'danger' ? 'warning' : signal.tone} />
            ))}
            <StatCard label="Mapa offline" value={central.offlineMapStatus.status} detail={central.offlineMapStatus.regionName} />
          </div>
        </Card>

        <Card title="Ultimas unidades activas" subtitle="Prioriza seguimiento rapido" className="saas-panel-dark">
          <div className="saas-vehicle-list">
            {central.drivers.slice(0, 4).map((driver) => (
              <VehicleStatusCard
                key={driver.id}
                title={getDriverDisplayName(driver)}
                subtitle={driver.phone || driver.status}
                status={getDriverStatusLabel(driver)}
                meta={getDriverTelemetryLabel(driver, 'Ping')}
                onClick={() => setSelectedDriverId(driver.id)}
              />
            ))}
          </div>
        </Card>
      </section>

      <Modal open={Boolean(selectedDriver)} title={selectedDriver ? getDriverDisplayName(selectedDriver) : 'Detalle del conductor'} onClose={() => setSelectedDriverId(null)}>
        {selectedDriver && (
          <div className="saas-detail-stack">
            <div className="saas-detail-row">
              <span>Nombre</span>
              <strong>{getDriverDisplayName(selectedDriver)}</strong>
            </div>
            <div className="saas-detail-row">
              <span>Telefono o ID</span>
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
              <strong>{selectedDriver.current_trip_id ? selectedDriver.current_trip_id.slice(0, 8) : 'Sin viaje asignado'}</strong>
            </div>
            <div className="saas-detail-row">
              <span>Ultimo ping</span>
              <strong>{getDriverTelemetryDateTimeLabel(selectedDriver, 'Sin GPS reciente')}</strong>
            </div>
          </div>
        )}
      </Modal>

      <OverviewSections
        promoSettings={central.promoSettings}
        trips={central.trips}
        pendingDrivers={central.pendingDrivers}
        pendingDevices={central.pendingDevices}
        loading={central.loading}
        driverAccessNote={central.driverAccessNote}
        supportReports={central.supportReports}
        notificationAudience={central.notificationAudience}
        notificationPhone={central.notificationPhone}
        notificationTitle={central.notificationTitle}
        notificationMessage={central.notificationMessage}
        notificationKind={central.notificationKind}
        onDriverAccessNoteChange={central.setDriverAccessNote}
        onUpdatePromoStatus={central.updatePromoStatus}
        onUpdateDriverAccess={central.updateDriverAccess}
        onUpdateDeviceStatus={central.updateDeviceStatus}
        onLoadHistory={central.loadUserHistory}
        onNotificationAudienceChange={central.setNotificationAudience}
        onNotificationPhoneChange={central.setNotificationPhone}
        onNotificationTitleChange={central.setNotificationTitle}
        onNotificationMessageChange={central.setNotificationMessage}
        onNotificationKindChange={central.setNotificationKind}
        onSendNotification={central.sendAdminNotification}
      />

      <section className="saas-two-column">
        <Card title="Actividad reciente" subtitle="Linea de tiempo institucional" className="saas-panel-dark">
          <ActivityPanel events={central.filteredActivityFeed.slice(0, 10)} />
        </Card>
        <Card title="Tendencia de servicio" subtitle="Placeholder visual premium" className="saas-panel-dark">
          <div className="saas-chart-placeholder">
            <div className="saas-chart-bars">
              {[42, 66, 58, 79, 71, 92, 84].map((height, index) => (
                <span key={index} style={{ height: `${height}%` }} />
              ))}
            </div>
            <div className="saas-chart-labels">
              <small>Lun</small>
              <small>Mar</small>
              <small>Mie</small>
              <small>Jue</small>
              <small>Vie</small>
              <small>Sab</small>
              <small>Dom</small>
            </div>
          </div>
        </Card>
      </section>
    </div>
  )
}
