import { Outlet } from 'react-router-dom'
import Navbar from '../components/navbar/Navbar'
import Sidebar from '../components/sidebar/Sidebar'
import Loader from '../components/common/Loader'
import { useAuth } from '../hooks/useAuth'
import { useCentral } from '../hooks/useCentral'

export default function MainLayout() {
  const { adminProfile, logout } = useAuth()
  const { adminSearch, setAdminSearch, refreshAll, loading, error, clearError } = useCentral()

  return (
    <main className="layout dashboard-shell">
      <Sidebar adminProfile={adminProfile} onRefresh={() => void refreshAll()} onLogout={logout} loading={loading} />
      <section className="dashboard-main">
        <Navbar search={adminSearch} onSearchChange={setAdminSearch} onRefresh={() => void refreshAll()} loading={loading} />
        {loading && <Loader label="Sincronizando central..." />}
        {error && (
          <div className="error-box" onClick={clearError} role="button">
            {error}
          </div>
        )}
        <Outlet />
      </section>
    </main>
  )
}
