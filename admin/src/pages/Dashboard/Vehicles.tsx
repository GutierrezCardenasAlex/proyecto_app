import { useMemo, useState } from 'react'
import Card from '../../components/cards/Card'
import Button from '../../components/common/Button'
import AdminModal from '../../components/dashboard/AdminModal'
import ConfirmDialog from '../../components/dashboard/ConfirmDialog'
import DevicesPanel from '../../components/dashboard/DevicesPanel'
import StatCard from '../../components/dashboard/StatCard'
import UserForm from '../../components/dashboard/UserForm'
import { useCentral } from '../../hooks/useCentral'

export default function VehiclesPage() {
  const central = useCentral()
  const [userModalOpen, setUserModalOpen] = useState(false)
  const [confirmDeleteOpen, setConfirmDeleteOpen] = useState(false)
  const [roleFilter, setRoleFilter] = useState<'all' | 'driver' | 'passenger'>('all')
  const selectedUser = central.selectedManagedUser
  const selectedName = selectedUser?.full_name || selectedUser?.phone || 'Usuario sin nombre'
  const selectedRoleLabel = central.managedUserForm.role === 'driver' ? 'Conductor' : 'Pasajero'
  const deletionRiskCount = (selectedUser?.total_trips ?? 0) + (selectedUser?.device_count ?? 0) + (selectedUser?.support_open_count ?? 0)
  const deletionRiskTone = deletionRiskCount >= 5 ? 'danger' : deletionRiskCount >= 1 ? 'warning' : 'safe'
  const deletionWarningMessage =
    deletionRiskTone === 'danger'
      ? 'La cuenta ya tiene historial operativo. Conviene revisar viajes, soporte y dispositivos antes de eliminarla.'
      : deletionRiskTone === 'warning'
        ? 'Existen relaciones parciales con esta cuenta. La eliminacion debe confirmarse conscientemente.'
        : 'No se detectan dependencias relevantes. La eliminacion tiene un impacto menor.'

  const filteredDevices = useMemo(() => {
    if (roleFilter === 'all') return central.allDevices
    return central.allDevices.filter((device) => device.role === roleFilter)
  }, [central.allDevices, roleFilter])

  function handleManageUser(userId: string) {
    const user = central.managedUsers.find((item) => item.user_id === userId)
    if (!user) return
    central.openEditUserForm(user)
    setUserModalOpen(true)
  }

  async function handleDeleteSelectedUser() {
    if (!central.selectedManagedUser) return
    await central.deleteManagedUser(central.selectedManagedUser)
    setConfirmDeleteOpen(false)
    setUserModalOpen(false)
  }

  async function handleSaveSelectedUser() {
    await central.saveManagedUser()
    setUserModalOpen(false)
  }

  return (
    <div className="saas-page-stack">
      <section className="admin-section-headline">
        <div>
          <span className="eyebrow">Cabina de activos</span>
          <h2>Vehiculos, equipos y acceso por usuario</h2>
          <p>
            Gestiona autorizaciones, reemplazos y trazabilidad de cada equipo desde una vista mas ejecutiva, ordenada y comoda para central.
          </p>
        </div>
        <div className="admin-section-actions">
          <Button variant="secondary">Vista operativa</Button>
          <Button>Revision de accesos</Button>
        </div>
      </section>

      <section className="admin-stats-grid">
        <StatCard label="Equipos registrados" value={`${filteredDevices.length}`} detail="Inventario visible en central" icon="🧭" />
        <StatCard
          label="Autorizados"
          value={`${filteredDevices.filter((device) => device.status === 'AUTORIZADO').length}`}
          detail="Listos para operar"
          icon="✅"
          tone="success"
        />
        <StatCard label="Pendientes" value={`${filteredDevices.filter((device) => device.status === 'PENDIENTE').length}`} detail="Esperando decision de central" icon="⏳" tone="warning" />
        <StatCard
          label="Bloqueados"
          value={`${filteredDevices.filter((device) => device.status === 'RECHAZADO').length}`}
          detail="Cuentas restringidas o rechazadas"
          icon="⛔"
          tone="neutral"
        />
      </section>

      <section className="saas-two-column admin-ops-grid">
        <Card
          title="Panel de vehiculos y equipos"
          subtitle={`${filteredDevices.length} registros visibles con control de acceso, reemplazo y trazabilidad`}
          className="saas-panel-dark"
          actions={
            <div className="admin-filter-tabs">
              <button type="button" className={roleFilter === 'all' ? 'admin-filter-tab active' : 'admin-filter-tab'} onClick={() => setRoleFilter('all')}>
                Todos
              </button>
              <button type="button" className={roleFilter === 'passenger' ? 'admin-filter-tab active' : 'admin-filter-tab'} onClick={() => setRoleFilter('passenger')}>
                Pasajeros
              </button>
              <button type="button" className={roleFilter === 'driver' ? 'admin-filter-tab active' : 'admin-filter-tab'} onClick={() => setRoleFilter('driver')}>
                Conductores
              </button>
            </div>
          }
        >
          <DevicesPanel
            devices={filteredDevices}
            embedded
            onManageUser={handleManageUser}
            onLoadHistory={central.loadUserHistory}
            onAuthorize={(deviceId) => central.updateDeviceStatus(deviceId, 'AUTORIZADO')}
            onReplace={central.replaceDevice}
            onBlock={(deviceId) => central.updateDeviceStatus(deviceId, 'RECHAZADO')}
          />
        </Card>

        <Card title="Control operativo" subtitle="Lectura rapida del impacto sobre la cuenta y sus equipos." className="saas-panel-dark">
          <div className="ops-summary-list">
            <div className="ops-summary-card">
              <span>Usuario seleccionado</span>
              <strong>{selectedUser ? selectedName : 'Selecciona un equipo para gestionar su usuario'}</strong>
              <p>{selectedUser ? `${selectedUser.phone} · ${selectedRoleLabel}` : 'Desde Gestionar usuario se abre la ficha editable.'}</p>
            </div>
            <div className="ops-summary-card">
              <span>Riesgo de eliminacion</span>
              <strong>{selectedUser ? `${deletionRiskCount} relaciones detectadas` : 'Sin analisis'}</strong>
              <p>{selectedUser ? deletionWarningMessage : 'La advertencia aparece cuando seleccionas una cuenta.'}</p>
            </div>
            <div className="ops-summary-card">
              <span>Recomendacion</span>
              <strong>{central.pendingDevices.length ? 'Prioriza autorizaciones pendientes' : 'Panel estable'}</strong>
              <p>
                {central.pendingDevices.length
                  ? `${central.pendingDevices.length} equipos estan esperando decision para seguir operando.`
                  : 'No hay bloqueos urgentes en el flujo de dispositivos.'}
              </p>
            </div>
          </div>
        </Card>
      </section>

      <AdminModal
        open={userModalOpen && Boolean(selectedUser)}
        onClose={() => setUserModalOpen(false)}
        title={selectedUser ? `Gestionar usuario · ${selectedName}` : 'Gestionar usuario'}
        subtitle="Ficha amplia para editar, revisar trazabilidad y decidir acciones sin salir del panel de vehiculos."
        size="xl"
      >
        {selectedUser && (
          <div className="admin-form-shell">
            <section className="admin-stats-grid">
              <StatCard label="Cuenta" value={selectedRoleLabel} detail={central.managedUserForm.phone || 'Sin telefono registrado'} icon="👤" />
              <StatCard label="Viajes" value={`${selectedUser.total_trips}`} detail="Historial total asociado" icon="🛣️" />
              <StatCard
                label="Equipos"
                value={`${selectedUser.device_count}`}
                detail={`${selectedUser.authorized_devices} autorizados / ${selectedUser.pending_devices} pendientes`}
                icon="📱"
                tone="warning"
              />
              <StatCard
                label="Soporte"
                value={`${selectedUser.support_open_count}`}
                detail="Casos abiertos actualmente"
                icon="🎧"
                tone={selectedUser.support_open_count > 0 ? 'warning' : 'success'}
              />
            </section>

            <section className={`modal-warning-box ${deletionRiskTone}`}>
              <div>
                <span className="modal-label">Advertencia antes de borrar</span>
                <strong>{deletionWarningMessage}</strong>
                <p>
                  Si eliminas esta cuenta, el usuario podra registrarse nuevamente desde cero y central perdera el acceso directo a esta ficha.
                </p>
              </div>
              <ul className="modal-warning-list">
                <li>Viajes asociados: {selectedUser.total_trips}</li>
                <li>Equipos asociados: {selectedUser.device_count}</li>
                <li>Soporte abierto: {selectedUser.support_open_count}</li>
              </ul>
            </section>

            <UserForm
              form={central.managedUserForm}
              mode="edit"
              loading={central.loading}
              onUpdateForm={central.updateManagedUserForm}
              onSubmit={() => void handleSaveSelectedUser()}
              onCancel={() => setUserModalOpen(false)}
            />

            <div className="admin-form-actions admin-form-actions--spread">
              <Button variant="danger" onClick={() => setConfirmDeleteOpen(true)} disabled={central.loading}>
                Eliminar usuario completo
              </Button>
            </div>
          </div>
        )}
      </AdminModal>

      <ConfirmDialog
        open={confirmDeleteOpen}
        onCancel={() => setConfirmDeleteOpen(false)}
        onConfirm={() => void handleDeleteSelectedUser()}
        loading={central.loading}
        title={selectedUser ? `Eliminar usuario · ${selectedName}` : 'Eliminar usuario'}
        message={
          selectedUser
            ? `Se eliminara la cuenta ${selectedName}. Tiene ${selectedUser.total_trips} viajes, ${selectedUser.device_count} equipos y ${selectedUser.support_open_count} casos de soporte asociados.`
            : 'Se eliminara la cuenta seleccionada.'
        }
        confirmLabel="Eliminar definitivamente"
      />
    </div>
  )
}
