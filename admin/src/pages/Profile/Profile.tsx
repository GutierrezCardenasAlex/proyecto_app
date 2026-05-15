import Card from '../../components/cards/Card'
import ExecutiveStrip from '../../components/dashboard/ExecutiveStrip'
import PageHero from '../../components/dashboard/PageHero'
import { useAuth } from '../../hooks/useAuth'
import { useCentral } from '../../hooks/useCentral'
import { VIEW_DESCRIPTIONS, VIEW_LABELS } from '../../utils/constants'

export default function ProfilePage() {
  const { adminProfile } = useAuth()
  const central = useCentral()

  return (
    <>
      <PageHero
        eyebrow="Central Flash Go / Potosi"
        title={VIEW_LABELS.profile}
        description={VIEW_DESCRIPTIONS.profile}
        metrics={[
          { label: 'Perfil', value: adminProfile?.fullName || adminProfile?.username || 'Central' },
          { label: 'Telefono', value: adminProfile?.phone || 'Sin numero' },
          { label: 'Ultimo refresh', value: central.lastUpdatedAt || 'Sin lectura' },
          { label: 'Usuarios', value: `${central.managedUsers.length}` },
        ]}
      />
      <ExecutiveStrip title="Perfil de central" subtitle="Datos institucionales y pulso actual de la operacion." signals={central.executiveSignals} />
      <div className="double-grid">
        <Card title="Identidad institucional" subtitle="Datos de acceso de la central">
          <div className="mini-stats-grid">
            <div className="mini-stat-card">
              <span>Usuario</span>
              <strong>{adminProfile?.username || 'central'}</strong>
            </div>
            <div className="mini-stat-card">
              <span>Nombre</span>
              <strong>{adminProfile?.fullName || 'Central Flash Go'}</strong>
            </div>
            <div className="mini-stat-card">
              <span>Telefono</span>
              <strong>{adminProfile?.phone || 'Sin numero'}</strong>
            </div>
            <div className="mini-stat-card">
              <span>Sesion</span>
              <strong>Activa</strong>
            </div>
          </div>
        </Card>
        <Card title="Salud operativa" subtitle="Lectura general del sistema">
          <div className="mini-stats-grid">
            <div className="mini-stat-card">
              <span>Flota visible</span>
              <strong>{central.drivers.length}</strong>
            </div>
            <div className="mini-stat-card">
              <span>Soporte abierto</span>
              <strong>{central.supportSummary.open}</strong>
            </div>
            <div className="mini-stat-card">
              <span>Dispositivos</span>
              <strong>{central.allDevices.length}</strong>
            </div>
            <div className="mini-stat-card">
              <span>Offline</span>
              <strong>{central.offlineMapStatus.status}</strong>
            </div>
          </div>
        </Card>
      </div>
    </>
  )
}
