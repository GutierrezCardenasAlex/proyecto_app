import Button from '../common/Button'
import type { ManagedUserForm } from '../../types/admin'

type Props = {
  form: ManagedUserForm
  mode: 'create' | 'edit'
  loading: boolean
  onUpdateForm: <K extends keyof ManagedUserForm>(field: K, value: ManagedUserForm[K]) => void
  onSubmit: () => void
  onCancel: () => void
}

export default function UserForm({ form, mode, loading, onUpdateForm, onSubmit, onCancel }: Props) {
  return (
    <div className="admin-form-shell">
      <section className="admin-form-section">
        <div className="admin-form-section__head">
          <div>
            <span className="eyebrow">Identidad</span>
            <h3>Datos base del usuario</h3>
          </div>
          <p>Completa la informacion principal para alta o actualizacion desde central.</p>
        </div>

        <div className="admin-form-grid">
          <label className="admin-field">
            <span>Telefono</span>
            <input value={form.phone} onChange={(event) => onUpdateForm('phone', event.target.value)} placeholder="+591..." />
          </label>

          <label className="admin-field">
            <span>Rol</span>
            <select value={form.role} onChange={(event) => onUpdateForm('role', event.target.value as 'passenger' | 'driver')}>
              <option value="passenger">Pasajero</option>
              <option value="driver">Conductor</option>
            </select>
          </label>

          <label className="admin-field">
            <span>Nombre</span>
            <input value={form.firstName} onChange={(event) => onUpdateForm('firstName', event.target.value)} placeholder="Nombre" />
          </label>

          <label className="admin-field">
            <span>Apellido</span>
            <input value={form.lastName} onChange={(event) => onUpdateForm('lastName', event.target.value)} placeholder="Apellido" />
          </label>

          <label className="admin-field">
            <span>Correo</span>
            <input value={form.email} onChange={(event) => onUpdateForm('email', event.target.value)} placeholder="correo@empresa.com" />
          </label>

          <label className="admin-field admin-field--wide">
            <span>Direccion o referencia</span>
            <input value={form.address} onChange={(event) => onUpdateForm('address', event.target.value)} placeholder="Direccion o referencia" />
          </label>
        </div>
      </section>

      <section className="admin-form-section">
        <div className="admin-form-section__head">
          <div>
            <span className="eyebrow">Seguridad</span>
            <h3>Acceso y perfil</h3>
          </div>
          <p>Controla la contrasena y el estado de finalizacion del perfil.</p>
        </div>

        <div className="admin-form-grid">
          <label className="admin-field">
            <span>{mode === 'create' ? 'Contrasena inicial' : 'Nueva contrasena'}</span>
            <input
              value={form.password}
              onChange={(event) => onUpdateForm('password', event.target.value)}
              placeholder={mode === 'create' ? 'Contrasena inicial' : 'Opcional'}
              type="password"
            />
          </label>

          <label className="admin-field admin-field--checkbox">
            <span>Estado del perfil</span>
            <div className="admin-checkbox-card">
              <input checked={form.profileCompleted} onChange={(event) => onUpdateForm('profileCompleted', event.target.checked)} type="checkbox" />
              <div>
                <strong>{form.profileCompleted ? 'Perfil completo' : 'Perfil pendiente'}</strong>
                <p>Usa este estado para diferenciar cuentas listas para operar.</p>
              </div>
            </div>
          </label>
        </div>
      </section>

      {form.role === 'driver' && (
        <section className="admin-form-section">
          <div className="admin-form-section__head">
            <div>
              <span className="eyebrow">Operacion</span>
              <h3>Campos del conductor</h3>
            </div>
            <p>Licencia y estado de acceso para mantener el control operativo.</p>
          </div>

          <div className="admin-form-grid">
            <label className="admin-field">
              <span>Numero de licencia</span>
              <input value={form.licenseNumber} onChange={(event) => onUpdateForm('licenseNumber', event.target.value)} placeholder="Numero de licencia" />
            </label>

            <label className="admin-field">
              <span>Estado de acceso</span>
              <select
                value={form.accessStatus}
                onChange={(event) => onUpdateForm('accessStatus', event.target.value as 'PENDIENTE' | 'AUTORIZADO' | 'RECHAZADO')}
              >
                <option value="PENDIENTE">Pendiente</option>
                <option value="AUTORIZADO">Autorizado</option>
                <option value="RECHAZADO">Rechazado</option>
              </select>
            </label>
          </div>
        </section>
      )}

      <div className="admin-form-actions">
        <Button variant="secondary" onClick={onCancel} disabled={loading}>
          Cancelar
        </Button>
        <Button onClick={onSubmit} disabled={loading}>
          {loading ? 'Guardando...' : mode === 'create' ? 'Crear usuario' : 'Actualizar usuario'}
        </Button>
      </div>
    </div>
  )
}
