import { useState } from 'react'
import Card from '../../components/cards/Card'
import Button from '../../components/common/Button'
import Modal from '../../components/common/Modal'
import DevicesPanel from '../../components/dashboard/DevicesPanel'
import MetricCard from '../../components/dashboard/MetricCard'
import { useCentral } from '../../hooks/useCentral'

export default function VehiclesPage() {
  const central = useCentral()
  const [userModalOpen, setUserModalOpen] = useState(false)
  const selectedUser = central.selectedManagedUser
  const selectedName = selectedUser?.full_name || selectedUser?.phone || 'Usuario sin nombre'
  const selectedRoleLabel = central.managedUserForm.role === 'driver' ? 'Conductor' : 'Pasajero'
  const deletionRiskCount = (selectedUser?.total_trips ?? 0) + (selectedUser?.device_count ?? 0) + (selectedUser?.support_open_count ?? 0)
  const deletionRiskTone =
    deletionRiskCount >= 5 ? 'danger' : deletionRiskCount >= 1 ? 'warning' : 'safe'
  const deletionWarningMessage =
    deletionRiskTone === 'danger'
      ? 'Este usuario ya tiene historial operativo. Antes de eliminarlo, revisa viajes, dispositivos y soporte vinculado.'
      : deletionRiskTone === 'warning'
        ? 'Hay registros asociados a esta cuenta. Central deberia confirmar el impacto antes de eliminarla.'
        : 'No se detectan asociaciones activas relevantes. La cuenta puede eliminarse con menor riesgo.'

  function handleManageUser(userId: string) {
    const user = central.managedUsers.find((item) => item.user_id === userId)
    if (!user) return
    central.openEditUserForm(user)
    setUserModalOpen(true)
  }

  async function handleDeleteSelectedUser() {
    if (!central.selectedManagedUser) return
    await central.deleteManagedUser(central.selectedManagedUser)
    setUserModalOpen(false)
  }

  async function handleSaveSelectedUser() {
    await central.saveManagedUser()
    setUserModalOpen(false)
  }

  return (
    <div className="saas-page-stack">
      <section className="saas-metric-grid">
        <MetricCard title="Equipos registrados" value={`${central.allDevices.length}`} icon="🧭" />
        <MetricCard title="Autorizados" value={`${central.allDevices.filter((device) => device.status === 'AUTORIZADO').length}`} tone="success" icon="✅" />
        <MetricCard title="Pendientes" value={`${central.pendingDevices.length}`} tone="warning" icon="⏳" />
        <MetricCard title="Bloqueados" value={`${central.allDevices.filter((device) => device.status === 'RECHAZADO').length}`} icon="⛔" />
      </section>

      <Card title="Panel de vehiculos y equipos" subtitle="Control de acceso, reemplazo y trazabilidad" className="saas-panel-dark">
        <DevicesPanel
          devices={central.allDevices}
          onManageUser={handleManageUser}
          onLoadHistory={central.loadUserHistory}
          onAuthorize={(deviceId) => central.updateDeviceStatus(deviceId, 'AUTORIZADO')}
          onReplace={central.replaceDevice}
          onBlock={(deviceId) => central.updateDeviceStatus(deviceId, 'RECHAZADO')}
        />
      </Card>

      <Modal
        open={userModalOpen && Boolean(selectedUser)}
        title={selectedUser ? `Gestionar usuario · ${selectedName}` : 'Gestionar usuario'}
        onClose={() => setUserModalOpen(false)}
      >
        <article className="user-management-modal">
          <section className="modal-summary-grid">
            <article className="modal-summary-card modal-summary-card-primary">
              <span className="modal-label">Cuenta seleccionada</span>
              <strong>{selectedName}</strong>
              <p>{central.managedUserForm.phone || 'Sin telefono registrado'}</p>
              <div className="modal-chip-row">
                <span className="modal-chip">{selectedRoleLabel}</span>
                <span className="modal-chip">{central.managedUserForm.profileCompleted ? 'Perfil completo' : 'Perfil pendiente'}</span>
                {selectedUser?.driver_access_status && <span className="modal-chip">{selectedUser.driver_access_status}</span>}
              </div>
            </article>
            <article className="modal-summary-card">
              <span className="modal-label">Trazabilidad</span>
              <strong>{selectedUser?.total_trips ?? 0} viajes</strong>
              <p>
                {selectedUser?.device_count ?? 0} equipos registrados · {selectedUser?.authorized_devices ?? 0} autorizados ·{' '}
                {selectedUser?.pending_devices ?? 0} pendientes
              </p>
            </article>
            <article className="modal-summary-card">
              <span className="modal-label">Soporte y actividad</span>
              <strong>{selectedUser?.support_open_count ?? 0} casos abiertos</strong>
              <p>
                ID usuario {selectedUser?.user_id?.slice(0, 8) ?? 'N/A'}
                {selectedUser?.driver_id ? ` · conductor ${selectedUser.driver_id.slice(0, 8)}` : ''}
              </p>
            </article>
          </section>

          <section className={`modal-warning-box ${deletionRiskTone}`}>
            <div>
              <span className="modal-label">Advertencia antes de borrar</span>
              <strong>{deletionWarningMessage}</strong>
              <p>
                Si eliminas completamente esta cuenta, central perdera el acceso directo a su ficha y el usuario podra volver a registrarse
                desde cero con el mismo telefono.
              </p>
            </div>
            <ul className="modal-warning-list">
              <li>Viajes asociados: {selectedUser?.total_trips ?? 0}</li>
              <li>Equipos asociados: {selectedUser?.device_count ?? 0}</li>
              <li>Soporte abierto: {selectedUser?.support_open_count ?? 0}</li>
            </ul>
          </section>

          <section className="modal-form-section">
            <div className="modal-section-head">
              <div>
                <span className="modal-label">Edicion de usuario</span>
                <h3>Datos principales</h3>
              </div>
              <p>Actualiza la informacion base y, si corresponde, los datos operativos del conductor.</p>
            </div>

            <div className="user-form-grid">
              <label className="modal-field">
                <span>Telefono</span>
                <input
                  value={central.managedUserForm.phone}
                  onChange={(event) => central.updateManagedUserForm('phone', event.target.value)}
                  placeholder="+591..."
                />
              </label>
              <label className="modal-field">
                <span>Rol</span>
                <select
                  value={central.managedUserForm.role}
                  onChange={(event) => central.updateManagedUserForm('role', event.target.value as 'passenger' | 'driver')}
                >
                  <option value="passenger">Pasajero</option>
                  <option value="driver">Conductor</option>
                </select>
              </label>
              <label className="modal-field">
                <span>Nombre</span>
                <input
                  value={central.managedUserForm.firstName}
                  onChange={(event) => central.updateManagedUserForm('firstName', event.target.value)}
                  placeholder="Nombre"
                />
              </label>
              <label className="modal-field">
                <span>Apellido</span>
                <input
                  value={central.managedUserForm.lastName}
                  onChange={(event) => central.updateManagedUserForm('lastName', event.target.value)}
                  placeholder="Apellido"
                />
              </label>
              <label className="modal-field">
                <span>Correo</span>
                <input
                  value={central.managedUserForm.email}
                  onChange={(event) => central.updateManagedUserForm('email', event.target.value)}
                  placeholder="correo@empresa.com"
                />
              </label>
              <label className="modal-field">
                <span>Direccion o referencia</span>
                <input
                  value={central.managedUserForm.address}
                  onChange={(event) => central.updateManagedUserForm('address', event.target.value)}
                  placeholder="Direccion o referencia"
                />
              </label>
              <label className="modal-field">
                <span>Nueva contrasena</span>
                <input
                  value={central.managedUserForm.password}
                  onChange={(event) => central.updateManagedUserForm('password', event.target.value)}
                  placeholder="Opcional"
                  type="password"
                />
              </label>
              <label className="inline-check modal-field modal-check-field">
                <input
                  checked={central.managedUserForm.profileCompleted}
                  onChange={(event) => central.updateManagedUserForm('profileCompleted', event.target.checked)}
                  type="checkbox"
                />
                <span>Perfil completo</span>
              </label>
              {central.managedUserForm.role === 'driver' && (
                <>
                  <label className="modal-field">
                    <span>Numero de licencia</span>
                    <input
                      value={central.managedUserForm.licenseNumber}
                      onChange={(event) => central.updateManagedUserForm('licenseNumber', event.target.value)}
                      placeholder="Numero de licencia"
                    />
                  </label>
                  <label className="modal-field">
                    <span>Estado de acceso</span>
                    <select
                      value={central.managedUserForm.accessStatus}
                      onChange={(event) =>
                        central.updateManagedUserForm('accessStatus', event.target.value as 'PENDIENTE' | 'AUTORIZADO' | 'RECHAZADO')
                      }
                    >
                      <option value="PENDIENTE">Pendiente</option>
                      <option value="AUTORIZADO">Autorizado</option>
                      <option value="RECHAZADO">Rechazado</option>
                    </select>
                  </label>
                </>
              )}
            </div>
          </section>

          <div className="action-row devices-actions-modal">
            <Button onClick={() => void handleSaveSelectedUser()} disabled={central.loading} className="uniform-button">
              {central.loading ? 'Guardando...' : 'Guardar cambios'}
            </Button>
            <Button variant="danger" onClick={() => void handleDeleteSelectedUser()} disabled={central.loading} className="uniform-button">
              Eliminar usuario completo
            </Button>
            <Button variant="secondary" onClick={() => setUserModalOpen(false)} className="uniform-button">
              Cerrar
            </Button>
          </div>
          <p className="subtitle modal-footer-note">
            Recomendacion: si el usuario tiene viajes, dispositivos o soporte abierto, revisa primero su historial antes de eliminarlo.
          </p>
        </article>
      </Modal>
    </div>
  )
}
