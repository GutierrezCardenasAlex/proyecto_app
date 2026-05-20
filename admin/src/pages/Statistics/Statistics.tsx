import StatCard from '../../components/dashboard/StatCard'
import StatsPanel from '../../components/dashboard/StatsPanel'
import { useCentral } from '../../hooks/useCentral'

export default function StatisticsPage() {
  const central = useCentral()

  return (
    <div className="saas-page-stack">
      <section className="admin-section-headline">
        <div>
          <span className="eyebrow">Performance operativo</span>
          <h2>Estadisticas, eficiencia y detalle por conductor</h2>
          <p>Una vista mas ejecutiva para revisar rendimiento, volumen de viajes y el detalle de choferes sin cambiar de contexto.</p>
        </div>
      </section>

      <section className="admin-stats-grid">
        <StatCard label="Viajes" value={`${central.driverPerformance.summary.totalTrips}`} detail="Volumen del periodo actual" icon="📊" />
        <StatCard label="Completados" value={`${central.driverPerformance.summary.completedTrips}`} detail="Cierres exitosos visibles" icon="✅" tone="success" />
        <StatCard label="Promo" value={`${central.driverPerformance.summary.promoTrips}`} detail="Impacto comercial del periodo" icon="🎁" tone="warning" />
        <StatCard label="Choferes activos" value={`${central.driverPerformance.summary.activeDrivers}`} detail="Participacion visible en el panel" icon="🧑" tone="neutral" />
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
    </div>
  )
}
