import Card from '../cards/Card'
import type { SupportReport } from '../../types/admin'
import { formatDateTime } from '../../utils/helpers'

type Props = {
  reports: SupportReport[]
  summary: { open: number; closed: number; passengers: number; drivers: number }
  roleFilter: 'all' | 'passenger' | 'driver'
  statusFilter: 'all' | 'ABIERTO' | 'CERRADO'
  search: string
  onRoleFilterChange: (value: 'all' | 'passenger' | 'driver') => void
  onStatusFilterChange: (value: 'all' | 'ABIERTO' | 'CERRADO') => void
  onSearchChange: (value: string) => void
}

export default function SupportPanel({
  reports,
  summary,
  roleFilter,
  statusFilter,
  search,
  onRoleFilterChange,
  onStatusFilterChange,
  onSearchChange,
}: Props) {
  return (
    <Card title="Reportes de soporte" subtitle={`${reports.length} visibles`}>
      <article className="list-card stack-card promo-card support-filters-card">
        <div className="mini-stats-grid support-summary-grid">
          <div className="mini-stat-card">
            <span>Abiertos</span>
            <strong>{summary.open}</strong>
          </div>
          <div className="mini-stat-card">
            <span>Cerrados</span>
            <strong>{summary.closed}</strong>
          </div>
          <div className="mini-stat-card">
            <span>Pasajeros</span>
            <strong>{summary.passengers}</strong>
          </div>
          <div className="mini-stat-card">
            <span>Conductores</span>
            <strong>{summary.drivers}</strong>
          </div>
        </div>
        <div className="support-filter-bar">
          <select value={roleFilter} onChange={(event) => onRoleFilterChange(event.target.value as 'all' | 'passenger' | 'driver')}>
            <option value="all">Todos los roles</option>
            <option value="passenger">Solo pasajeros</option>
            <option value="driver">Solo conductores</option>
          </select>
          <select value={statusFilter} onChange={(event) => onStatusFilterChange(event.target.value as 'all' | 'ABIERTO' | 'CERRADO')}>
            <option value="all">Todos los estados</option>
            <option value="ABIERTO">Abiertos</option>
            <option value="CERRADO">Cerrados</option>
          </select>
          <input value={search} onChange={(event) => onSearchChange(event.target.value)} placeholder="Buscar por nombre, telefono, categoria o mensaje" />
        </div>
      </article>

      <div className="list">
        {reports.length === 0 && <article className="list-card">No hay reportes con esos filtros.</article>}
        {reports.map((report) => (
          <article key={report.id} className="support-card">
            <div className="support-card-top">
              <div>
                <strong>{report.full_name || report.phone}</strong>
                <p>{report.role} · {report.phone}</p>
              </div>
              <div className="support-badges">
                <span className="status-pill warning subtle">{report.category}</span>
                <span className={report.status === 'ABIERTO' ? 'status-pill warning subtle' : 'status-pill success subtle'}>
                  {report.status}
                </span>
              </div>
            </div>
            <div className="support-message">{report.message}</div>
            <div className="support-card-footer">
              <span>Enviado</span>
              <strong>{formatDateTime(report.created_at)}</strong>
            </div>
          </article>
        ))}
      </div>
    </Card>
  )
}
