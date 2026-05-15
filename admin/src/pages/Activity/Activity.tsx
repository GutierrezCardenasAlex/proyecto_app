import ActivityPanel from '../../components/dashboard/ActivityPanel'
import ExecutiveStrip from '../../components/dashboard/ExecutiveStrip'
import PageHero from '../../components/dashboard/PageHero'
import { useCentral } from '../../hooks/useCentral'
import { VIEW_DESCRIPTIONS, VIEW_LABELS } from '../../utils/constants'

export default function ActivityPage() {
  const central = useCentral()

  return (
    <>
      <PageHero
        eyebrow="Central Flash Go / Potosi"
        title={VIEW_LABELS.activity}
        description={VIEW_DESCRIPTIONS.activity}
        metrics={[
          { label: 'Eventos', value: `${central.filteredActivityFeed.length}` },
          { label: 'Soporte abierto', value: `${central.supportSummary.open}` },
          { label: 'Equipos pendientes', value: `${central.pendingDevices.length}` },
          { label: 'Conductores pendientes', value: `${central.pendingDrivers.length}` },
        ]}
      />
      <ExecutiveStrip title="Linea de tiempo operativa" subtitle="Eventos recientes concentrados en una sola vista." signals={central.executiveSignals} />
      <ActivityPanel events={central.filteredActivityFeed} />
    </>
  )
}
