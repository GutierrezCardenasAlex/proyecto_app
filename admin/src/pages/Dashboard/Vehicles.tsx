import Card from '../../components/cards/Card'
import DevicesPanel from '../../components/dashboard/DevicesPanel'
import MetricCard from '../../components/dashboard/MetricCard'
import { useCentral } from '../../hooks/useCentral'

export default function VehiclesPage() {
  const central = useCentral()

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
          onLoadHistory={central.loadUserHistory}
          onAuthorize={(deviceId) => central.updateDeviceStatus(deviceId, 'AUTORIZADO')}
          onReplace={central.replaceDevice}
          onBlock={(deviceId) => central.updateDeviceStatus(deviceId, 'RECHAZADO')}
        />
      </Card>
    </div>
  )
}
