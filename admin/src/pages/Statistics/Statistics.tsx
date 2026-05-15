import ExecutiveStrip from '../../components/dashboard/ExecutiveStrip'
import PageHero from '../../components/dashboard/PageHero'
import StatsPanel from '../../components/dashboard/StatsPanel'
import { useCentral } from '../../hooks/useCentral'
import { VIEW_DESCRIPTIONS, VIEW_LABELS } from '../../utils/constants'

export default function StatisticsPage() {
  const central = useCentral()

  return (
    <>
      <PageHero
        eyebrow="Central Flash Go / Potosi"
        title={VIEW_LABELS.stats}
        description={VIEW_DESCRIPTIONS.stats}
        metrics={[
          { label: 'Viajes', value: `${central.driverPerformance.summary.totalTrips}` },
          { label: 'Completados', value: `${central.driverPerformance.summary.completedTrips}` },
          { label: 'Promo', value: `${central.driverPerformance.summary.promoTrips}` },
          { label: 'Choferes activos', value: `${central.driverPerformance.summary.activeDrivers}` },
        ]}
      />
      <ExecutiveStrip title="Rendimiento de conductores" subtitle="Seguimiento por eficiencia, volumen y detalle de viajes." signals={central.executiveSignals} />
      <StatsPanel
        performanceRange={central.performanceRange}
        driverPerformance={central.driverPerformance}
        selectedDriverTrips={central.selectedDriverTrips}
        loading={central.loading}
        onChangeRange={central.loadDriverPerformance}
        onLoadTrips={central.loadDriverTrips}
        onCloseTrips={central.closeDriverTrips}
      />
    </>
  )
}
