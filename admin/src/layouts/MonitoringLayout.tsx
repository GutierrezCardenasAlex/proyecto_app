import { Outlet, useLocation } from 'react-router-dom'
import { useMemo } from 'react'
import { useAuth } from '../hooks/useAuth'
import { useCentral } from '../hooks/useCentral'
import { APP_ROUTES, PAGE_META } from '../utils/constants'

export default function MonitoringLayout() {
  const location = useLocation()
  const { logoutMonitor } = useAuth()
  const { loading, refreshAll } = useCentral()

  const pageMeta = useMemo(() => PAGE_META[location.pathname as keyof typeof PAGE_META] ?? PAGE_META[APP_ROUTES.monitoring], [location.pathname])

  return (
    <div className="monitor-shell">
      <header className="monitor-topbar">
        <div>
          <span className="eyebrow">Monitoreo RAPIGO</span>
          <strong>{pageMeta.title}</strong>
          <p>{pageMeta.subtitle}</p>
        </div>
        <div className="monitor-actions">
          <button type="button" className={loading ? 'saas-status-badge syncing' : 'saas-status-badge'} onClick={() => void refreshAll()}>
            {loading ? 'Sincronizando' : 'Actualizar mapa'}
          </button>
          <button type="button" className="saas-logout-button" onClick={logoutMonitor}>
            Salir de monitoreo
          </button>
        </div>
      </header>

      <main className="monitor-content">
        <Outlet />
      </main>
    </div>
  )
}
