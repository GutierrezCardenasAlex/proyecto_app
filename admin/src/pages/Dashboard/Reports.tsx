import ActivityPanel from '../../components/dashboard/ActivityPanel'
import Card from '../../components/cards/Card'
import MetricCard from '../../components/dashboard/MetricCard'
import StatsPanel from '../../components/dashboard/StatsPanel'
import SupportPanel from '../../components/dashboard/SupportPanel'
import { useCentral } from '../../hooks/useCentral'

export default function ReportsPage() {
  const central = useCentral()

  return (
    <div className="saas-page-stack">
      <section className="saas-metric-grid">
        <MetricCard title="Viajes del periodo" value={`${central.driverPerformance.summary.totalTrips}`} icon="📊" />
        <MetricCard title="Completados" value={`${central.driverPerformance.summary.completedTrips}`} tone="success" icon="✅" />
        <MetricCard title="Soporte abierto" value={`${central.supportSummary.open}`} tone="warning" icon="🎧" />
        <MetricCard title="Actividad visible" value={`${central.filteredActivityFeed.length}`} icon="⚡" />
      </section>

      <StatsPanel
        performanceRange={central.performanceRange}
        driverPerformance={central.driverPerformance}
        selectedDriverTrips={central.selectedDriverTrips}
        loading={central.loading}
        onChangeRange={central.loadDriverPerformance}
        onLoadTrips={central.loadDriverTrips}
        onCloseTrips={central.closeDriverTrips}
      />

      <section className="saas-two-column">
        <Card title="Actividad reciente" subtitle="Eventos y acciones recientes" className="saas-panel-dark">
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
