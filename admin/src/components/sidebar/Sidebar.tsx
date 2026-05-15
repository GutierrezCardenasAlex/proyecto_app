import { NavLink } from 'react-router-dom'
import Button from '../common/Button'
import { NAV_ITEMS } from '../../utils/constants'
import type { AdminProfile } from '../../types/admin'

type Props = {
  adminProfile: AdminProfile | null
  onRefresh: () => void
  onLogout: () => void
  loading: boolean
}

export default function Sidebar({ adminProfile, onRefresh, onLogout, loading }: Props) {
  return (
    <aside className="panel nav-shell">
      <div className="nav-brand">
        <p className="eyebrow">Flash Go Executive</p>
        <h2>Cabina central</h2>
        <p>{adminProfile?.fullName || adminProfile?.username || 'Central'} · {adminProfile?.phone}</p>
      </div>

      <nav className="nav-menu">
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')}
          >
            <strong>{item.label}</strong>
            <span>{item.hint}</span>
          </NavLink>
        ))}
      </nav>

      <div className="nav-footer">
        <Button onClick={onRefresh} disabled={loading}>
          {loading ? 'Actualizando...' : 'Actualizar central'}
        </Button>
        <Button variant="secondary" onClick={onLogout}>
          Cerrar sesion
        </Button>
      </div>
    </aside>
  )
}
