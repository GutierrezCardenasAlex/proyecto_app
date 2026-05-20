import StatCard from '../../components/dashboard/StatCard'
import SupportPanel from '../../components/dashboard/SupportPanel'
import { useCentral } from '../../hooks/useCentral'

export default function SupportPage() {
  const central = useCentral()

  return (
    <div className="saas-page-stack">
      <section className="admin-section-headline">
        <div>
          <span className="eyebrow">Mesa de atencion</span>
          <h2>Soporte, filtros y estado de casos</h2>
          <p>Seguimiento mas limpio de reportes abiertos y cerrados, con una lectura rapida por rol para responder desde central sin perder visibilidad.</p>
        </div>
      </section>

      <section className="admin-stats-grid">
        <StatCard label="Abiertos" value={`${central.supportSummary.open}`} detail="Casos esperando atencion" icon="🎧" tone="warning" />
        <StatCard label="Cerrados" value={`${central.supportSummary.closed}`} detail="Casos ya resueltos" icon="✅" tone="success" />
        <StatCard label="Pasajeros" value={`${central.supportSummary.passengers}`} detail="Reportes provenientes de clientes" icon="🧑" tone="neutral" />
        <StatCard label="Conductores" value={`${central.supportSummary.drivers}`} detail="Incidencias del lado de flota" icon="🚕" />
      </section>

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
    </div>
  )
}
