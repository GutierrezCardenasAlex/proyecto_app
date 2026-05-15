import Button from '../common/Button'
import Card from '../cards/Card'
import type { ManagedUserForm, ManagedUserRow, UserSummary } from '../../types/admin'

type Props = {
  users: ManagedUserRow[]
  form: ManagedUserForm
  mode: 'create' | 'edit'
  selectedUser: ManagedUserRow | null
  loading: boolean
  onOpenCreate: () => void
  onOpenEdit: (user: ManagedUserRow) => void
  onUpdateForm: <K extends keyof ManagedUserForm>(field: K, value: ManagedUserForm[K]) => void
  onSave: () => Promise<void>
  onDelete: (user: ManagedUserRow) => Promise<void>
  onLoadHistory: (user: UserSummary) => Promise<void>
}

export default function UsersCrudPanel({
  users,
  form,
  mode,
  selectedUser,
  loading,
  onOpenCreate,
  onOpenEdit,
  onUpdateForm,
  onSave,
  onDelete,
  onLoadHistory,
}: Props) {
  return (
    <div className="double-grid">
      <Card title="Usuarios de central" subtitle={`${users.length} usuarios visibles`}>
        <div className="list directory-list">
          {users.map((user) => (
            <article key={user.user_id} className="list-card stack-card">
              <div>
                <strong>{user.full_name || user.phone}</strong>
                <p>{user.role} · {user.phone}</p>
                <p>{user.device_count} equipos · {user.total_trips} viajes · {user.support_open_count} soporte abierto</p>
              </div>
              <div className="action-row compact">
                <span className={user.role === 'driver' ? 'status-pill warning subtle' : 'status-pill success subtle'}>
                  {user.role === 'driver' ? 'Chofer' : 'Pasajero'}
                </span>
                {user.role === 'driver' && user.driver_access_status && (
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
                <Button variant="secondary" onClick={() => onOpenEdit(user)}>
                  Editar
                </Button>
                <Button variant="secondary" onClick={() => onLoadHistory(user)}>
                  Historial
                </Button>
                <Button variant="danger" onClick={() => onDelete(user)}>
                  Eliminar
                </Button>
              </div>
            </article>
          ))}
        </div>
      </Card>

      <Card title={mode === 'create' ? 'Crear usuario' : 'Editar usuario'} subtitle={mode === 'create' ? 'Alta directa desde central' : selectedUser?.full_name || selectedUser?.phone}>
        <article className="list-card stack-card promo-card">
          <div className="user-form-grid">
            <input value={form.phone} onChange={(event) => onUpdateForm('phone', event.target.value)} placeholder="+591..." />
            <select value={form.role} onChange={(event) => onUpdateForm('role', event.target.value as 'passenger' | 'driver')}>
              <option value="passenger">Pasajero</option>
              <option value="driver">Conductor</option>
            </select>
            <input value={form.firstName} onChange={(event) => onUpdateForm('firstName', event.target.value)} placeholder="Nombre" />
            <input value={form.lastName} onChange={(event) => onUpdateForm('lastName', event.target.value)} placeholder="Apellido" />
            <input value={form.email} onChange={(event) => onUpdateForm('email', event.target.value)} placeholder="correo@empresa.com" />
            <input value={form.address} onChange={(event) => onUpdateForm('address', event.target.value)} placeholder="Direccion o referencia" />
            <input
              value={form.password}
              onChange={(event) => onUpdateForm('password', event.target.value)}
              placeholder={mode === 'create' ? 'Contrasena inicial' : 'Nueva contrasena (opcional)'}
              type="password"
            />
            <label className="inline-check">
              <input checked={form.profileCompleted} onChange={(event) => onUpdateForm('profileCompleted', event.target.checked)} type="checkbox" />
              <span>Perfil completo</span>
            </label>
            {form.role === 'driver' && (
              <>
                <input
                  value={form.licenseNumber}
                  onChange={(event) => onUpdateForm('licenseNumber', event.target.value)}
                  placeholder="Numero de licencia"
                />
                <select
                  value={form.accessStatus}
                  onChange={(event) =>
                    onUpdateForm('accessStatus', event.target.value as 'PENDIENTE' | 'AUTORIZADO' | 'RECHAZADO')
                  }
                >
                  <option value="PENDIENTE">Pendiente</option>
                  <option value="AUTORIZADO">Autorizado</option>
                  <option value="RECHAZADO">Rechazado</option>
                </select>
              </>
            )}
          </div>
          <div className="action-row">
            <Button onClick={() => void onSave()} disabled={loading}>
              {loading ? 'Guardando...' : mode === 'create' ? 'Crear usuario' : 'Guardar cambios'}
            </Button>
            <Button variant="secondary" onClick={onOpenCreate}>
              Nuevo formulario
            </Button>
          </div>
        </article>
      </Card>
    </div>
  )
}
