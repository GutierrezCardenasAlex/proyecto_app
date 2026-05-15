import Card from '../../components/cards/Card'
import ActivityPanel from '../../components/dashboard/ActivityPanel'
import MetricCard from '../../components/dashboard/MetricCard'
import OverviewSections from '../../components/dashboard/OverviewSections'
import VehicleStatusCard from '../../components/dashboard/VehicleStatusCard'
import { useCentral } from '../../hooks/useCentral'

export default function DashboardHome() {
  const central = useCentral()
  const activeDrivers = central.drivers.filter((driver) => driver.is_available)
  const revenue = Number(central.dashboard.revenue || 0).toFixed(2)

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
              <div key={signal.label} className={`saas-health-card ${signal.tone}`}>
                <span>{signal.label}</span>
                <strong>{signal.value}</strong>
              </div>
            ))}
            <div className="saas-health-card accent">
              <span>Mapa offline</span>
              <strong>{central.offlineMapStatus.status}</strong>
            </div>
          </div>
        </Card>

        <Card title="Ultimas unidades activas" subtitle="Prioriza seguimiento rapido" className="saas-panel-dark">
          <div className="saas-vehicle-list">
            {central.drivers.slice(0, 4).map((driver) => (
              <VehicleStatusCard
                key={driver.id}
                title={`Conductor ${driver.id.slice(0, 8)}`}
                subtitle={driver.status}
                status={driver.current_trip_id ? 'En viaje' : driver.is_available ? 'Disponible' : 'Desconectado'}
                meta={driver.location?.updatedAt ? `Ping ${new Date(driver.location.updatedAt).toLocaleTimeString('es-BO')}` : 'Sin GPS reciente'}
              />
            ))}
          </div>
        </Card>
      </section>

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
