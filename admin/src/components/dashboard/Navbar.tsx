type Props = {
  title: string
  subtitle: string
  search: string
  loading: boolean
  onSearchChange: (value: string) => void
  onToggleMenu: () => void
}

function BurgerIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M4 7h16" />
      <path d="M4 12h16" />
      <path d="M4 17h16" />
    </svg>
  )
}

function BellIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M15 17h5l-1.4-1.4A2 2 0 0 1 18 14.2V11a6 6 0 1 0-12 0v3.2a2 2 0 0 1-.6 1.4L4 17h5" />
      <path d="M10 21a2 2 0 0 0 4 0" />
    </svg>
  )
}

export default function DashboardNavbar({ title, subtitle, search, loading, onSearchChange, onToggleMenu }: Props) {
  return (
    <header className="saas-navbar">
      <div className="saas-navbar-left">
        <button type="button" className="saas-burger" onClick={onToggleMenu} aria-label="Mostrar u ocultar menu lateral">
          <BurgerIcon />
        </button>
        <div className="saas-navbar-copy">
          <strong>{title}</strong>
          <span>{subtitle}</span>
        </div>
      </div>

      <div className="saas-navbar-right">
        <label className="saas-search">
          <input
            value={search}
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder="Buscar conductor, unidad, viaje o usuario"
          />
        </label>
        <button type="button" className="saas-icon-button">
          <BellIcon />
        </button>
        <div className={loading ? 'saas-status-badge syncing' : 'saas-status-badge'}>{loading ? 'Sincronizando' : 'Central en vivo'}</div>
      </div>
    </header>
  )
}
