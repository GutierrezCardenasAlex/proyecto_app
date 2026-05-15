import UserHistoryPanel from '../../components/dashboard/UserHistoryPanel'
import UsersCrudPanel from '../../components/dashboard/UsersCrudPanel'
import MetricCard from '../../components/dashboard/MetricCard'
import { useCentral } from '../../hooks/useCentral'

export default function DashboardUsersPage() {
  const central = useCentral()

  return (
    <div className="saas-page-stack">
      <section className="saas-metric-grid">
        <MetricCard title="Usuarios visibles" value={`${central.filteredManagedUsers.length}`} icon="👥" />
        <MetricCard title="Conductores" value={`${central.filteredManagedUsers.filter((user) => user.role === 'driver').length}`} tone="warning" icon="🚕" />
        <MetricCard title="Pasajeros" value={`${central.filteredManagedUsers.filter((user) => user.role !== 'driver').length}`} tone="success" icon="🧑" />
        <MetricCard title="Historial cargado" value={`${central.userHistory.length}`} icon="🕘" />
      </section>

      <UsersCrudPanel
        users={central.filteredManagedUsers}
        form={central.managedUserForm}
        mode={central.userFormMode}
        selectedUser={central.selectedManagedUser}
        loading={central.loading}
        onOpenCreate={central.openCreateUserForm}
        onOpenEdit={central.openEditUserForm}
        onUpdateForm={central.updateManagedUserForm}
        onSave={central.saveManagedUser}
        onDelete={central.deleteManagedUser}
        onLoadHistory={central.loadUserHistory}
      />

      <UserHistoryPanel
        user={central.selectedHistoryUser}
        phoneDraft={central.phoneDraft}
        history={central.userHistory}
        loading={central.loading}
        onPhoneChange={central.setPhoneDraft}
        onSavePhone={central.changeUserPhone}
        onAuthorizeDevice={(deviceId) => central.updateDeviceStatus(deviceId, 'AUTORIZADO')}
        onReplaceDevice={central.replaceDevice}
        onBlockDevice={(deviceId) => central.updateDeviceStatus(deviceId, 'RECHAZADO')}
      />
    </div>
  )
}
