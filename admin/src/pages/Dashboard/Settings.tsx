import Button from '../../components/common/Button'
import Card from '../../components/cards/Card'
import StatCard from '../../components/dashboard/StatCard'
import { useAuth } from '../../hooks/useAuth'
import { useCentral } from '../../hooks/useCentral'
import { formatDateTime } from '../../utils/helpers'

export default function SettingsPage() {
  const { adminProfile, logout } = useAuth()
  const central = useCentral()

  return (
    <div className="saas-page-stack">
      <section className="admin-section-headline">
        <div>
          <span className="eyebrow">Centro de control</span>
          <h2>Configuracion, perfil institucional y politicas operativas</h2>
          <p>
            Ajusta el estado del modo offline, promociones y lectura institucional de la sesion sin salir de una vista mas clara para produccion.
          </p>
        </div>
        <div className="admin-section-actions">
          <Button variant="secondary" onClick={() => void logout()}>
            Cerrar sesion
          </Button>
        </div>
      </section>

      <section className="admin-stats-grid">
        <StatCard label="Central" value={adminProfile?.fullName || adminProfile?.username || 'Central'} detail="Sesion institucional activa" icon="🏢" />
        <StatCard label="Offline" value={central.offlineMapStatus.status} detail={central.offlineMapStatus.regionName} icon="🗺️" tone="warning" />
        <StatCard label="Promociones" value={central.promoSettings.enabled ? 'Activas' : 'Pausadas'} detail={`Cada ${central.promoSettings.cycleLength} viajes`} icon="🎁" tone="success" />
        <StatCard label="Ultima sincronizacion" value={central.lastUpdatedAt || 'Sin dato'} detail="Reloj operativo del panel" icon="🕒" tone="neutral" />
      </section>

      <section className="settings-page-grid">
        <Card title="Perfil institucional" subtitle="Datos visibles de la central y estado actual de la sesion." className="saas-panel-dark">
          <div className="settings-stack">
            <div className="admin-detail-card">
              <span>Usuario</span>
              <strong>{adminProfile?.username || 'centralrapigo'}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Nombre</span>
              <strong>{adminProfile?.fullName || 'Central RAPIGO'}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Telefono</span>
              <strong>{adminProfile?.phone || 'Sin telefono'}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Nivel de acceso</span>
              <strong>{adminProfile?.accessLevel === 'monitor' ? 'Monitoreo' : 'Administracion'}</strong>
            </div>
          </div>
        </Card>

        <Card title="Mapa offline y origen" subtitle="Estado de la fuente, region y disponibilidad local." className="saas-panel-dark">
          <div className="settings-stack">
            <div className="admin-detail-card">
              <span>Modo offline</span>
              <strong>{central.offlineMapStatus.status}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Region</span>
              <strong>{central.offlineMapStatus.regionName}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Fuente</span>
              <strong>{central.offlineMapStatus.sourceType}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Host</span>
              <strong>{central.offlineMapStatus.sourceHost || 'Sin host expuesto'}</strong>
            </div>
          </div>
        </Card>

        <Card title="Promociones y reglas" subtitle="Control comercial y estado actual del ciclo de beneficios." className="saas-panel-dark">
          <div className="settings-toggle-panel">
            <div className="settings-toggle-panel__copy">
              <span className="eyebrow">Promociones</span>
              <h3>{central.promoSettings.enabled ? 'Motor promocional activo' : 'Motor promocional pausado'}</h3>
              <p>
                Ciclo actual: una recompensa cada {central.promoSettings.cycleLength} viajes con {central.promoSettings.rewardCredits} credito(s).
              </p>
              <small>Actualizado: {formatDateTime(central.promoSettings.updatedAt, 'Sin fecha registrada')}</small>
            </div>
            <Button
              variant={central.promoSettings.enabled ? 'danger' : 'success'}
              onClick={() => void central.updatePromoStatus(!central.promoSettings.enabled)}
            >
              {central.promoSettings.enabled ? 'Pausar promociones' : 'Activar promociones'}
            </Button>
          </div>
        </Card>

        <Card title="Semaforo operativo" subtitle="Lectura rapida del estado general del panel." className="saas-panel-dark">
          <div className="settings-inline-kpis">
            <div className="settings-inline-kpis__item">
              <span>Usuarios</span>
              <strong>{central.managedUsers.length}</strong>
            </div>
            <div className="settings-inline-kpis__item">
              <span>Equipos</span>
              <strong>{central.allDevices.length}</strong>
            </div>
            <div className="settings-inline-kpis__item">
              <span>Incidencias</span>
              <strong>{central.supportSummary.open}</strong>
            </div>
          </div>
        </Card>
      </section>
    </div>
  )
}
