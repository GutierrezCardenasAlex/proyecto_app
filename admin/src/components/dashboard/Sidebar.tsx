import { NavLink } from 'react-router-dom'
import { DASHBOARD_NAV_ITEMS } from '../../utils/constants'

type Props = {
  theme: 'dark' | 'light'
  collapsed: boolean
  mobileOpen: boolean
  loading: boolean
  onCloseMobile: () => void
  onToggleCollapse: () => void
  onToggleTheme: () => void
  onRefresh: () => void
  onLogout: () => void
}

function CloseIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M18 6 6 18" />
      <path d="m6 6 12 12" />
    </svg>
  )
}

function PanelToggleIcon({ collapsed }: { collapsed: boolean }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="16" rx="3" />
      <path d={collapsed ? 'M9 4v16' : 'M15 4v16'} />
    </svg>
  )
}

function Icon({ name }: { name: string }) {
  const common = { width: 20, height: 20, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const }
  switch (name) {
    case 'map':
      return <svg {...common}><path d="M9 18 3 20V6l6-2 6 2 6-2v14l-6 2-6-2Z" /><path d="M9 4v14" /><path d="M15 6v14" /></svg>
    case 'drivers':
      return <svg {...common}><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M22 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></svg>
    case 'vehicles':
      return <svg {...common}><path d="M14 16H9m10 0h2m-2 0a2 2 0 1 1 0 4 2 2 0 0 1 0-4Zm-14 0a2 2 0 1 1 0 4 2 2 0 0 1 0-4Zm0 0H3m2 0 1.5-4.5A2 2 0 0 1 8.4 10h7.2a2 2 0 0 1 1.9 1.5L19 16M7 6h10" /></svg>
    case 'trips':
      return <svg {...common}><path d="m3 17 6-6 4 4 8-8" /><path d="M14 7h7v7" /></svg>
    case 'users':
      return <svg {...common}><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></svg>
    case 'reports':
      return <svg {...common}><path d="M3 3h18v18H3z" /><path d="M7 15V9" /><path d="M12 15V6" /><path d="M17 15v-3" /></svg>
    case 'settings':
      return <svg {...common}><path d="M12 1v4" /><path d="M12 19v4" /><path d="m4.93 4.93 2.83 2.83" /><path d="m16.24 16.24 2.83 2.83" /><path d="M1 12h4" /><path d="M19 12h4" /><path d="m4.93 19.07 2.83-2.83" /><path d="m16.24 7.76 2.83-2.83" /><circle cx="12" cy="12" r="4" /></svg>
    case 'dashboard':
    default:
      return <svg {...common}><rect x="3" y="3" width="8" height="8" rx="2" /><rect x="13" y="3" width="8" height="5" rx="2" /><rect x="13" y="10" width="8" height="11" rx="2" /><rect x="3" y="13" width="8" height="8" rx="2" /></svg>
  }
}

export default function DashboardSidebar({
  theme,
  collapsed,
  mobileOpen,
  loading,
  onCloseMobile,
  onToggleCollapse,
  onToggleTheme,
  onRefresh,
  onLogout,
}: Props) {
  const isOpen = mobileOpen || !collapsed

  return (
    <aside className={`saas-sidebar ${collapsed ? 'is-collapsed' : 'is-expanded'} ${mobileOpen ? 'mobile-open' : ''}`.trim()}>
      <div className="saas-sidebar-brand">
        <div className="saas-brand-lockup">
          <div className="saas-logo-mark">FG</div>
          {isOpen && (
            <div>
              <strong>Flash Go Fleet</strong>
              <span>Executive Mobility Hub</span>
            </div>
          )}
        </div>
        <div className="saas-sidebar-brand-actions">
          <button type="button" className="saas-sidebar-rail-toggle" onClick={onToggleCollapse} aria-label="Ajustar ancho del menu">
            <PanelToggleIcon collapsed={collapsed} />
          </button>
          <button type="button" className="saas-sidebar-close" onClick={onCloseMobile} aria-label="Cerrar menu">
            <CloseIcon />
          </button>
        </div>
      </div>

      <nav className="saas-nav">
        {DASHBOARD_NAV_ITEMS.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) => (isActive ? 'saas-nav-item active' : 'saas-nav-item')}
            onClick={onCloseMobile}
          >
            <span className="saas-nav-icon"><Icon name={item.icon} /></span>
            {isOpen && (
              <span className="saas-nav-copy">
                <strong>{item.label}</strong>
                <small>{item.hint}</small>
              </span>
            )}
          </NavLink>
        ))}
      </nav>

      <div className={isOpen ? 'saas-sidebar-footer' : 'saas-sidebar-footer hidden'}>
        <div className="saas-sidebar-footer-copy">
          <strong>Cabina administrativa</strong>
          <span>Accesos, operacion y trazabilidad centralizada.</span>
        </div>
        <div className="saas-sidebar-footer-actions">
          <button type="button" className="saas-ghost-button compact" onClick={onToggleCollapse}>
            {collapsed ? 'Expandir' : 'Reducir'}
          </button>
          <button type="button" className="saas-ghost-button compact" onClick={onToggleTheme}>
            {theme === 'dark' ? 'Claro' : 'Oscuro'}
          </button>
          <button type="button" className="saas-ghost-button compact" onClick={onRefresh} disabled={loading}>
            {loading ? 'Sync...' : 'Sync'}
          </button>
          <button type="button" className="saas-danger-link compact" onClick={onLogout}>
            Salir
          </button>
        </div>
      </div>
    </aside>
  )
}
