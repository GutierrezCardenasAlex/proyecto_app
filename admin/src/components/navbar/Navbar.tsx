import Button from '../common/Button'

type Props = {
  search: string
  onSearchChange: (value: string) => void
  onRefresh: () => void
  loading: boolean
}

export default function Navbar({ search, onSearchChange, onRefresh, loading }: Props) {
  return (
    <section className="panel dashboard-topbar">
      <div className="dashboard-topbar-copy">
        <strong>Centro de mando</strong>
        <span>Vista ejecutiva para monitoreo, respuesta y control institucional.</span>
      </div>
      <div className="dashboard-topbar-actions">
        <label className="search-shell">
          <input
            value={search}
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder="Buscar conductor, usuario, viaje o evento..."
          />
        </label>
        <span className="status-pill warning">Central en vivo</span>
        <Button variant="secondary" onClick={onRefresh} disabled={loading}>
          {loading ? 'Sincronizando...' : 'Sincronizar'}
        </Button>
      </div>
    </section>
  )
}
