import DevicesPanel from '../../components/dashboard/DevicesPanel'
import ExecutiveStrip from '../../components/dashboard/ExecutiveStrip'
import PageHero from '../../components/dashboard/PageHero'
import UserHistoryPanel from '../../components/dashboard/UserHistoryPanel'
import { useCentral } from '../../hooks/useCentral'
import { VIEW_DESCRIPTIONS, VIEW_LABELS } from '../../utils/constants'

export default function DevicesPage() {
  const central = useCentral()

  return (
    <>
      <PageHero
        eyebrow="Central Flash Go / Potosi"
        title={VIEW_LABELS.devices}
        description={VIEW_DESCRIPTIONS.devices}
        metrics={[
          { label: 'Registrados', value: `${central.allDevices.length}` },
          { label: 'Pendientes', value: `${central.pendingDevices.length}` },
          { label: 'Bloqueados', value: `${central.allDevices.filter((device) => device.status === 'RECHAZADO').length}` },
          { label: 'Autorizados', value: `${central.allDevices.filter((device) => device.status === 'AUTORIZADO').length}` },
        ]}
      />
      <ExecutiveStrip title="Gobierno de dispositivos" subtitle="Autorizaciones, reemplazos y trazabilidad por usuario." signals={central.executiveSignals} />
      <DevicesPanel
        devices={central.allDevices}
        onLoadHistory={central.loadUserHistory}
        onAuthorize={(deviceId) => central.updateDeviceStatus(deviceId, 'AUTORIZADO')}
        onReplace={central.replaceDevice}
        onBlock={(deviceId) => central.updateDeviceStatus(deviceId, 'RECHAZADO')}
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
