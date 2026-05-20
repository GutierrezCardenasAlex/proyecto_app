type Props = {
  title: string
  subtitle: string
  search: string
  theme: 'dark' | 'light'
  sidebarCollapsed: boolean
  loading: boolean
  onLogout: () => void
  onSearchChange: (value: string) => void
  onToggleMenu: () => void
  onToggleTheme: () => void
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

function ThemeIcon({ theme }: { theme: 'dark' | 'light' }) {
  if (theme === 'dark') {
    return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2" />
        <path d="M12 20v2" />
        <path d="m4.93 4.93 1.41 1.41" />
        <path d="m17.66 17.66 1.41 1.41" />
        <path d="M2 12h2" />
        <path d="M20 12h2" />
        <path d="m6.34 17.66-1.41 1.41" />
        <path d="m19.07 4.93-1.41 1.41" />
      </svg>
    )
  }

  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M21 12.79A9 9 0 1 1 11.21 3c0 5.34 4.45 9.79 9.79 9.79Z" />
    </svg>
  )
}

export default function DashboardNavbar({
  title,
  subtitle,
  search,
  theme,
  sidebarCollapsed,
  loading,
  onLogout,
  onSearchChange,
  onToggleMenu,
  onToggleTheme,
}: Props) {
  return (
    <header className="saas-navbar">
      <div className="saas-navbar-left">
        <button type="button" className={sidebarCollapsed ? 'saas-burger collapsed' : 'saas-burger'} onClick={onToggleMenu} aria-label="Mostrar u ocultar menu lateral">
          <BurgerIcon />
          <span className="saas-burger-label">{sidebarCollapsed ? 'Expandir' : 'Panel'}</span>
        </button>
        <div className="saas-navbar-copy">
          <strong>{title}</strong>
          <span>{subtitle}</span>
        </div>
      </div>

      <div className="saas-navbar-right">
        <label className="saas-search">
          <span className="saas-search-icon">⌕</span>
          <input
            value={search}
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder="Buscar conductor, unidad, viaje o usuario"
          />
        </label>
        <button type="button" className="saas-icon-button">
          <BellIcon />
        </button>
        <button type="button" className="saas-icon-button saas-theme-button" onClick={onToggleTheme} aria-label="Cambiar tema del panel">
          <ThemeIcon theme={theme} />
        </button>
        <div className={loading ? 'saas-status-badge syncing' : 'saas-status-badge'}>{loading ? 'Sincronizando' : 'Central en vivo'}</div>
        <button type="button" className="saas-logout-button" onClick={onLogout}>
          Cerrar sesion
        </button>
      </div>
    </header>
  )
}
