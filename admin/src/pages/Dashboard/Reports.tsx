import ActivityPanel from '../../components/dashboard/ActivityPanel'
import Card from '../../components/cards/Card'
import DriverReportsPanel from '../../components/dashboard/DriverReportsPanel'
import StatCard from '../../components/dashboard/StatCard'
import SupportPanel from '../../components/dashboard/SupportPanel'
import { useCentral } from '../../hooks/useCentral'

export default function ReportsPage() {
  const central = useCentral()
  const supportTotal = central.supportSummary.open + central.supportSummary.closed
  const revenueFormatted = new Intl.NumberFormat('es-BO', {
    style: 'currency',
    currency: 'BOB',
    maximumFractionDigits: 0,
  }).format(central.driverPerformance.summary.revenue || 0)

  return (
    <div className="saas-page-stack">
      <section className="admin-section-headline">
        <div>
          <span className="eyebrow">Analitica operativa</span>
          <h2>Reportes, performance y actividad consolidada</h2>
          <p>
            Una vista mas seria para leer tendencias, validar el rendimiento de conductores y seguir soporte y actividad sin perder contexto.
          </p>
        </div>
      </section>

      <section className="admin-stats-grid">
        <StatCard label="Viajes del periodo" value={`${central.driverPerformance.summary.totalTrips}`} detail="Base del reporte seleccionado" icon="📊" />
        <StatCard label="Completados" value={`${central.driverPerformance.summary.completedTrips}`} detail="Viajes cerrados con exito" icon="✅" tone="success" />
        <StatCard label="Soporte abierto" value={`${central.supportSummary.open}`} detail="Casos que requieren seguimiento" icon="🎧" tone="warning" />
        <StatCard label="Ingresos" value={revenueFormatted} detail="Acumulado visible del periodo" icon="💰" tone="neutral" />
      </section>

      <section className="saas-two-column report-insight-grid">
        <Card title="Lectura ejecutiva" subtitle="Resumen de lo que mas importa para esta ventana de analisis." className="saas-panel-dark">
          <div className="ops-summary-list">
            <div className="ops-summary-card">
              <span>Conductores activos</span>
              <strong>{central.driverPerformance.summary.activeDrivers}</strong>
              <p>Choferes con participacion visible en el periodo actual.</p>
            </div>
            <div className="ops-summary-card">
              <span>Viajes promocionales</span>
              <strong>{central.driverPerformance.summary.promoTrips}</strong>
              <p>Impacto de promociones y ciclos comerciales sobre la operacion.</p>
            </div>
            <div className="ops-summary-card">
              <span>Actividad visible</span>
              <strong>{central.filteredActivityFeed.length}</strong>
              <p>Eventos recientes filtrados y listos para revision por central.</p>
            </div>
          </div>
        </Card>

        <Card title="Estado del frente de soporte" subtitle="Severidad operativa y pendientes de seguimiento." className="saas-panel-dark">
          <div className="settings-inline-kpis">
            <div className="settings-inline-kpis__item">
              <span>Abiertos</span>
              <strong>{central.supportSummary.open}</strong>
            </div>
            <div className="settings-inline-kpis__item">
              <span>Resueltos</span>
              <strong>{central.supportSummary.closed}</strong>
            </div>
            <div className="settings-inline-kpis__item">
              <span>Total</span>
              <strong>{supportTotal}</strong>
            </div>
          </div>
        </Card>
      </section>

      <DriverReportsPanel
        performanceRange={central.performanceRange}
        driverPerformance={central.driverPerformance}
        selectedDriverTrips={central.selectedDriverTrips}
        loading={central.loading}
        onChangeRange={central.loadDriverPerformance}
        onLoadTrips={central.loadDriverTrips}
        onCloseTrips={central.closeDriverTrips}
      />

      <section className="saas-two-column">
        <Card title="Actividad reciente" subtitle="Eventos, cambios y acciones reportadas por la central." className="saas-panel-dark">
          <ActivityPanel events={central.filteredActivityFeed} />
        </Card>
        <SupportPanel
          reports={central.filteredSupportReports}
          summary={central.supportSummary}
          roleFilter={central.supportRoleFilter}
          statusFilter={central.supportStatusFilter}
          search={central.supportSearch}
          onRoleFilterChange={central.setSupportRoleFilter}
          onStatusFilterChange={central.setSupportStatusFilter}
          onSearchChange={central.setSupportSearch}
        />
      </section>
    </div>
  )
}
