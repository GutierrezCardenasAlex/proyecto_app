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
        open={userModalOpen && Boolean(central.selectedManagedUser)}
        title={central.selectedManagedUser ? `Gestionar usuario · ${central.selectedManagedUser.full_name || central.selectedManagedUser.phone}` : 'Gestionar usuario'}
        onClose={() => setUserModalOpen(false)}
      >
        <article className="list-card stack-card promo-card">
          <div className="user-form-grid">
            <input
              value={central.managedUserForm.phone}
              onChange={(event) => central.updateManagedUserForm('phone', event.target.value)}
              placeholder="+591..."
            />
            <select
              value={central.managedUserForm.role}
              onChange={(event) => central.updateManagedUserForm('role', event.target.value as 'passenger' | 'driver')}
            >
              <option value="passenger">Pasajero</option>
              <option value="driver">Conductor</option>
            </select>
            <input
              value={central.managedUserForm.firstName}
              onChange={(event) => central.updateManagedUserForm('firstName', event.target.value)}
              placeholder="Nombre"
            />
            <input
              value={central.managedUserForm.lastName}
              onChange={(event) => central.updateManagedUserForm('lastName', event.target.value)}
              placeholder="Apellido"
            />
            <input
              value={central.managedUserForm.email}
              onChange={(event) => central.updateManagedUserForm('email', event.target.value)}
              placeholder="correo@empresa.com"
            />
            <input
              value={central.managedUserForm.address}
              onChange={(event) => central.updateManagedUserForm('address', event.target.value)}
              placeholder="Direccion o referencia"
            />
            <input
              value={central.managedUserForm.password}
              onChange={(event) => central.updateManagedUserForm('password', event.target.value)}
              placeholder="Nueva contrasena (opcional)"
              type="password"
            />
            <label className="inline-check">
              <input
                checked={central.managedUserForm.profileCompleted}
                onChange={(event) => central.updateManagedUserForm('profileCompleted', event.target.checked)}
                type="checkbox"
              />
              <span>Perfil completo</span>
            </label>
            {central.managedUserForm.role === 'driver' && (
              <>
                <input
                  value={central.managedUserForm.licenseNumber}
                  onChange={(event) => central.updateManagedUserForm('licenseNumber', event.target.value)}
                  placeholder="Numero de licencia"
                />
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
              </>
            )}
          </div>

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
          <p className="subtitle">
            Si eliminas completamente la cuenta, el usuario podra registrarse de nuevo desde cero con ese telefono.
          </p>
        </article>
      </Modal>
    </div>
  )
}
