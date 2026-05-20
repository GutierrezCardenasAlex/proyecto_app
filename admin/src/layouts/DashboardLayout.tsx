import { Outlet, useLocation } from 'react-router-dom'
import { useEffect, useMemo, useState } from 'react'
import Loader from '../components/common/Loader'
import DashboardNavbar from '../components/dashboard/Navbar'
import DashboardSidebar from '../components/dashboard/Sidebar'
import { useAuth } from '../hooks/useAuth'
import { useCentral } from '../hooks/useCentral'
import { PAGE_META } from '../utils/constants'

export default function DashboardLayout() {
  const location = useLocation()
  const { logout } = useAuth()
  const { adminSearch, setAdminSearch, refreshAll, loading, error, clearError } = useCentral()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [theme, setTheme] = useState<'dark' | 'light'>(() => {
    if (typeof window === 'undefined') return 'dark'
    const stored = window.localStorage.getItem('flashgo-admin-theme')
    return stored === 'light' ? 'light' : 'dark'
  })

  const pageMeta = useMemo(() => {
    const found = Object.entries(PAGE_META)
      .sort((a, b) => b[0].length - a[0].length)
      .find(([path]) => location.pathname === path)
    return found?.[1] ?? PAGE_META['/dashboard']
  }, [location.pathname])

  function handleToggleMenu() {
    const isMobileViewport = typeof window !== 'undefined' && window.innerWidth <= 960
    if (isMobileViewport) {
      setMobileMenuOpen((current) => !current)
      return
    }
    setSidebarCollapsed((current) => !current)
  }

  function handleToggleTheme() {
    setTheme((current) => (current === 'dark' ? 'light' : 'dark'))
  }

  useEffect(() => {
    if (typeof document === 'undefined') return
    document.body.classList.remove('admin-theme-dark', 'admin-theme-light')
    document.body.classList.add(theme === 'dark' ? 'admin-theme-dark' : 'admin-theme-light')
    window.localStorage.setItem('flashgo-admin-theme', theme)
  }, [theme])

  return (
    <div className="saas-shell">
      <DashboardSidebar
        theme={theme}
        collapsed={sidebarCollapsed}
        mobileOpen={mobileMenuOpen}
        loading={loading}
        onCloseMobile={() => setMobileMenuOpen(false)}
        onToggleCollapse={() => setSidebarCollapsed((current) => !current)}
        onToggleTheme={handleToggleTheme}
        onRefresh={() => void refreshAll()}
        onLogout={logout}
      />

      {mobileMenuOpen && (
        <button
          type="button"
          className="saas-overlay"
          aria-label="Cerrar menu"
          onClick={() => {
            setMobileMenuOpen(false)
          }}
        />
      )}

      <div className={sidebarCollapsed ? 'saas-main collapsed' : 'saas-main'}>
        <DashboardNavbar
          title={pageMeta.title}
          subtitle={pageMeta.subtitle}
          search={adminSearch}
          theme={theme}
          sidebarCollapsed={sidebarCollapsed}
          loading={loading}
          onLogout={logout}
          onSearchChange={setAdminSearch}
          onToggleMenu={handleToggleMenu}
          onToggleTheme={handleToggleTheme}
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
