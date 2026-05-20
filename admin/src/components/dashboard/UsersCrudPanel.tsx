import { useMemo, useState } from 'react'
import Button from '../common/Button'
import Card from '../cards/Card'
import type { ManagedUserForm, ManagedUserRow, UserSummary } from '../../types/admin'
import AdminModal from './AdminModal'
import ConfirmDialog from './ConfirmDialog'
import StatCard from './StatCard'
import UserForm from './UserForm'
import UserTable from './UserTable'

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
  const [formOpen, setFormOpen] = useState(false)
  const [detailUser, setDetailUser] = useState<ManagedUserRow | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<ManagedUserRow | null>(null)

  const summary = useMemo(
    () => ({
      drivers: users.filter((user) => user.role === 'driver').length,
      passengers: users.filter((user) => user.role === 'passenger').length,
      actives: users.filter((user) => user.profile_completed).length,
      recent: users.slice(0, 5).length,
    }),
    [users],
  )

  function handleCreate() {
    onOpenCreate()
    setFormOpen(true)
  }

  function handleEdit(user: ManagedUserRow) {
    onOpenEdit(user)
    setFormOpen(true)
  }

  async function handleSave() {
    await onSave()
    setFormOpen(false)
  }

  async function handleDelete() {
    if (!deleteTarget) return
    await onDelete(deleteTarget)
    setDeleteTarget(null)
  }

  return (
    <>
      <section className="admin-section-shell">
        <div className="admin-section-headline">
          <div>
            <span className="eyebrow">Gestion de usuarios</span>
            <h2>Control administrativo limpio, rapido y con contexto operativo</h2>
            <p>Visualiza, crea, actualiza y depura cuentas desde una experiencia unificada y lista para produccion.</p>
          </div>
          <div className="admin-section-actions">
            <Button variant="secondary" onClick={() => selectedUser && setDetailUser(selectedUser)} disabled={!selectedUser}>
              Ver ultimo usuario editado
            </Button>
            <Button onClick={handleCreate}>Crear usuario</Button>
          </div>
        </div>

        <div className="admin-stats-grid">
          <StatCard label="Usuarios visibles" value={`${users.length}`} detail="Filtrados por la busqueda actual" icon="👥" />
          <StatCard label="Conductores" value={`${summary.drivers}`} detail="Con ficha operativa asociada" icon="🚕" tone="warning" />
          <StatCard label="Pasajeros" value={`${summary.passengers}`} detail="Listos para gestion comercial" icon="🧑" tone="success" />
          <StatCard label="Perfiles completos" value={`${summary.actives}`} detail={`${summary.recent} registros recientes`} icon="✨" tone="neutral" />
        </div>
      </section>

      <Card
        title="Directorio administrativo"
        subtitle={`${users.length} usuarios visibles con acciones rapidas, estados y trazabilidad`}
        actions={
          <Button variant="secondary" onClick={handleCreate}>
            Nuevo usuario
          </Button>
        }
      >
        <UserTable users={users} onView={setDetailUser} onEdit={handleEdit} onDelete={setDeleteTarget} onLoadHistory={onLoadHistory} />
      </Card>

      <AdminModal
        open={formOpen}
        onClose={() => setFormOpen(false)}
        title={mode === 'create' ? 'Crear usuario' : `Editar usuario · ${selectedUser?.full_name || selectedUser?.phone || 'Cuenta seleccionada'}`}
        subtitle={mode === 'create' ? 'Alta directa desde central con formulario amplio y ordenado.' : 'Actualiza la ficha sin salir del panel.'}
        actions={null}
      >
        <UserForm form={form} mode={mode} loading={loading} onUpdateForm={onUpdateForm} onSubmit={() => void handleSave()} onCancel={() => setFormOpen(false)} />
      </AdminModal>

      <AdminModal
        open={Boolean(detailUser)}
        onClose={() => setDetailUser(null)}
        title={detailUser?.full_name || detailUser?.phone || 'Detalle del usuario'}
        subtitle="Resumen rapido para lectura ejecutiva y control operativo."
        size="lg"
      >
        {detailUser && (
          <div className="detail-modal-grid">
            <StatCard label="Rol" value={detailUser.role === 'driver' ? 'Conductor' : 'Pasajero'} detail="Tipo de cuenta operativa" tone={detailUser.role === 'driver' ? 'warning' : 'success'} />
            <StatCard label="Viajes" value={`${detailUser.total_trips}`} detail="Historial total acumulado" />
            <StatCard label="Equipos" value={`${detailUser.device_count}`} detail={`${detailUser.authorized_devices} autorizados / ${detailUser.pending_devices} pendientes`} />
            <StatCard label="Soporte" value={`${detailUser.support_open_count}`} detail="Casos abiertos actualmente" tone={detailUser.support_open_count > 0 ? 'warning' : 'success'} />

            <div className="admin-detail-card">
              <span>Telefono</span>
              <strong>{detailUser.phone}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Correo</span>
              <strong>{detailUser.email || 'Sin correo registrado'}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Direccion</span>
              <strong>{detailUser.address || 'Sin direccion registrada'}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Perfil</span>
              <strong>{detailUser.profile_completed ? 'Completo' : 'Pendiente'}</strong>
            </div>
          </div>
        )}
      </AdminModal>

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        onCancel={() => setDeleteTarget(null)}
        onConfirm={() => void handleDelete()}
        loading={loading}
        title={deleteTarget ? `Eliminar usuario · ${deleteTarget.full_name || deleteTarget.phone}` : 'Eliminar usuario'}
        message={
          deleteTarget
            ? `Se eliminara la cuenta ${deleteTarget.full_name || deleteTarget.phone}. Tiene ${deleteTarget.total_trips} viajes, ${deleteTarget.device_count} equipos y ${deleteTarget.support_open_count} casos de soporte asociados.`
            : 'Se eliminara la cuenta seleccionada.'
        }
        confirmLabel="Eliminar definitivamente"
      />
    </>
  )
}
