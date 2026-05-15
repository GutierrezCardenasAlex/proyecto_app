import { Outlet, useLocation } from 'react-router-dom'
import { useMemo, useState } from 'react'
import Loader from '../components/common/Loader'
import DashboardNavbar from '../components/dashboard/Navbar'
import DashboardSidebar from '../components/dashboard/Sidebar'
import { useAuth } from '../hooks/useAuth'
import { useCentral } from '../hooks/useCentral'
import { PAGE_META } from '../utils/constants'

export default function DashboardLayout() {
  const location = useLocation()
  const { adminProfile, logout } = useAuth()
  const { adminSearch, setAdminSearch, refreshAll, loading, error, clearError } = useCentral()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)

  const pageMeta = useMemo(() => {
    const found = Object.entries(PAGE_META)
      .sort((a, b) => b[0].length - a[0].length)
      .find(([path]) => location.pathname === path)
    return found?.[1] ?? PAGE_META['/dashboard']
  }, [location.pathname])

  return (
    <div className="saas-shell">
      <DashboardSidebar
        adminProfile={adminProfile}
        collapsed={sidebarCollapsed}
        mobileOpen={mobileMenuOpen}
        loading={loading}
        onCloseMobile={() => setMobileMenuOpen(false)}
        onToggleCollapse={() => setSidebarCollapsed((current) => !current)}
        onRefresh={() => void refreshAll()}
        onLogout={logout}
      />

      {mobileMenuOpen && <button type="button" className="saas-overlay" aria-label="Cerrar menu" onClick={() => setMobileMenuOpen(false)} />}

      <div className={sidebarCollapsed ? 'saas-main collapsed' : 'saas-main'}>
        <DashboardNavbar
          title={pageMeta.title}
          subtitle={pageMeta.subtitle}
          search={adminSearch}
          loading={loading}
          onSearchChange={setAdminSearch}
          onToggleMobileMenu={() => setMobileMenuOpen(true)}
        />

        <section className="saas-content">
          {loading && <Loader label="Sincronizando la central..." />}
          {error && (
            <button type="button" className="saas-alert-banner" onClick={clearError}>
              {error}
            </button>
          )}
          <Outlet />
        </section>
      </div>
    </div>
  )
}
