import ExecutiveStrip from '../../components/dashboard/ExecutiveStrip'
import PageHero from '../../components/dashboard/PageHero'
import SupportPanel from '../../components/dashboard/SupportPanel'
import { useCentral } from '../../hooks/useCentral'
import { VIEW_DESCRIPTIONS, VIEW_LABELS } from '../../utils/constants'

export default function SupportPage() {
  const central = useCentral()

  return (
    <>
      <PageHero
        eyebrow="Central Flash Go / Potosi"
        title={VIEW_LABELS.support}
        description={VIEW_DESCRIPTIONS.support}
        metrics={[
          { label: 'Abiertos', value: `${central.supportSummary.open}` },
          { label: 'Cerrados', value: `${central.supportSummary.closed}` },
          { label: 'Pasajeros', value: `${central.supportSummary.passengers}` },
          { label: 'Conductores', value: `${central.supportSummary.drivers}` },
        ]}
      />
      <ExecutiveStrip title="Mesa de atencion" subtitle="Filtros visibles para respuesta mas rapida y clara." signals={central.executiveSignals} />
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
    </>
  )
}
