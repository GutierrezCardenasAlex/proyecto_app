import Card from '../../components/cards/Card'
import MetricCard from '../../components/dashboard/MetricCard'
import { useAuth } from '../../hooks/useAuth'
import { useCentral } from '../../hooks/useCentral'

export default function SettingsPage() {
  const { adminProfile } = useAuth()
  const central = useCentral()

  return (
    <div className="saas-page-stack">
      <section className="saas-metric-grid">
        <MetricCard title="Central" value={adminProfile?.fullName || adminProfile?.username || 'Central'} icon="🏢" />
        <MetricCard title="Offline" value={central.offlineMapStatus.status} tone="warning" icon="🗺️" />
        <MetricCard title="Promociones" value={central.promoSettings.enabled ? 'Activas' : 'Pausadas'} tone="success" icon="🎁" />
        <MetricCard title="Sincronizacion" value={central.lastUpdatedAt || 'Sin dato'} icon="🕒" />
      </section>

      <section className="saas-two-column">
        <Card title="Perfil institucional" subtitle="Datos visibles de la central" className="saas-panel-dark">
          <div className="saas-detail-stack">
            <div className="saas-detail-row"><span>Usuario</span><strong>{adminProfile?.username || 'centralflashgo'}</strong></div>
            <div className="saas-detail-row"><span>Nombre</span><strong>{adminProfile?.fullName || 'Central Flash Go'}</strong></div>
            <div className="saas-detail-row"><span>Telefono</span><strong>{adminProfile?.phone || 'Sin telefono'}</strong></div>
            <div className="saas-detail-row"><span>Sesion</span><strong>Activa</strong></div>
          </div>
        </Card>

        <Card title="Configuracion operativa" subtitle="Promociones y offline" className="saas-panel-dark">
          <div className="saas-detail-stack">
            <div className="saas-detail-row"><span>Modo offline</span><strong>{central.offlineMapStatus.status}</strong></div>
            <div className="saas-detail-row"><span>Region</span><strong>{central.offlineMapStatus.regionName}</strong></div>
            <div className="saas-detail-row"><span>Fuente</span><strong>{central.offlineMapStatus.sourceType}</strong></div>
            <div className="saas-detail-row"><span>Promociones</span><strong>{central.promoSettings.enabled ? 'Habilitadas' : 'Pausadas'}</strong></div>
          </div>
          <div className="action-row">
            <button type="button" className={central.promoSettings.enabled ? 'danger-button' : 'success-button'} onClick={() => void central.updatePromoStatus(!central.promoSettings.enabled)}>
              {central.promoSettings.enabled ? 'Pausar promociones' : 'Activar promociones'}
            </button>
          </div>
        </Card>
      </section>
    </div>
  )
}
