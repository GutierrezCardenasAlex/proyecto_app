import ExecutiveStrip from '../../components/dashboard/ExecutiveStrip'
import PageHero from '../../components/dashboard/PageHero'
import UserHistoryPanel from '../../components/dashboard/UserHistoryPanel'
import UsersCrudPanel from '../../components/dashboard/UsersCrudPanel'
import { useCentral } from '../../hooks/useCentral'
import { VIEW_DESCRIPTIONS, VIEW_LABELS } from '../../utils/constants'

export default function UsersPage() {
  const central = useCentral()

  return (
    <>
      <PageHero
        eyebrow="Central RAPIGO / Potosi"
        title={VIEW_LABELS.users}
        description={VIEW_DESCRIPTIONS.users}
        metrics={[
          { label: 'Directorio', value: `${central.filteredManagedUsers.length}` },
          { label: 'Conductores', value: `${central.filteredManagedUsers.filter((user) => user.role === 'driver').length}` },
          { label: 'Pasajeros', value: `${central.filteredManagedUsers.filter((user) => user.role !== 'driver').length}` },
          { label: 'Historiales', value: `${central.userHistory.length}` },
        ]}
      />
      <ExecutiveStrip title="CRUD centralizado" subtitle="Altas, cambios y bajas sin salir del panel." signals={central.executiveSignals} />
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
    </>
  )
}
