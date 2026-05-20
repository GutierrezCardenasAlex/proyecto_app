import type { ManagedUserRow, UserSummary } from '../../types/admin'

type Props = {
  users: ManagedUserRow[]
  onView: (user: ManagedUserRow) => void
  onEdit: (user: ManagedUserRow) => void
  onDelete: (user: ManagedUserRow) => void
  onLoadHistory: (user: UserSummary) => void
}

function ActionIcon({ type }: { type: 'view' | 'edit' | 'delete' | 'history' }) {
  const common = {
    width: 16,
    height: 16,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.8,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
  }

  switch (type) {
    case 'edit':
      return <svg {...common}><path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 1 1 3 3L7 19l-4 1 1-4 12.5-12.5Z" /></svg>
    case 'delete':
      return <svg {...common}><path d="M3 6h18" /><path d="M8 6V4h8v2" /><path d="M19 6l-1 14H6L5 6" /></svg>
    case 'history':
      return <svg {...common}><path d="M3 12a9 9 0 1 0 3-6.7" /><path d="M3 3v6h6" /><path d="M12 7v5l4 2" /></svg>
    case 'view':
    default:
      return <svg {...common}><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" /><circle cx="12" cy="12" r="3" /></svg>
  }
}

export default function UserTable({ users, onView, onEdit, onDelete, onLoadHistory }: Props) {
  if (!users.length) {
    return (
      <div className="admin-empty-state">
        <strong>No hay usuarios para mostrar</strong>
        <p>Cuando existan registros visibles apareceran aqui con accesos rapidos para ver, editar o eliminar.</p>
      </div>
    )
  }

  return (
    <div className="admin-user-table">
      <div className="admin-user-table__head">
        <span>Usuario</span>
        <span>Rol y estado</span>
        <span>Actividad</span>
        <span>Acciones</span>
      </div>

      <div className="admin-user-table__body">
        {users.map((user) => (
          <article key={user.user_id} className="admin-user-row">
            <div className="admin-user-main">
              <strong>{user.full_name || user.phone}</strong>
              <p>{user.phone}</p>
              <small>{user.email || 'Sin correo registrado'}</small>
            </div>

            <div className="admin-user-meta">
              <span className={`status-pill ${user.role === 'driver' ? 'warning' : 'success'}`}>{user.role === 'driver' ? 'Conductor' : 'Pasajero'}</span>
              {user.driver_access_status && (
                <span
                  className={
                    user.driver_access_status === 'AUTORIZADO'
                      ? 'status-pill success subtle'
                      : user.driver_access_status === 'RECHAZADO'
                        ? 'status-pill danger subtle'
                        : 'status-pill warning subtle'
                  }
                >
                  {user.driver_access_status}
                </span>
              )}
            </div>

            <div className="admin-user-stats">
              <span>{user.device_count} equipos</span>
              <span>{user.total_trips} viajes</span>
              <span>{user.support_open_count} soporte abierto</span>
            </div>

            <div className="admin-row-actions">
              <button type="button" className="admin-icon-action" onClick={() => onView(user)} aria-label="Ver detalle">
                <ActionIcon type="view" />
              </button>
              <button type="button" className="admin-icon-action" onClick={() => onEdit(user)} aria-label="Editar usuario">
                <ActionIcon type="edit" />
              </button>
              <button
                type="button"
                className="admin-icon-action"
                onClick={() =>
                  onLoadHistory({
                    user_id: user.user_id,
                    phone: user.phone,
                    full_name: user.full_name,
                    role: user.role,
                  })
                }
                aria-label="Ver historial"
              >
                <ActionIcon type="history" />
              </button>
              <button type="button" className="admin-icon-action danger" onClick={() => onDelete(user)} aria-label="Eliminar usuario">
                <ActionIcon type="delete" />
              </button>
            </div>
          </article>
        ))}
      </div>
    </div>
  )
}
