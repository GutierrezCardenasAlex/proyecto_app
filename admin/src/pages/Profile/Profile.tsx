import Card from '../../components/cards/Card'
import StatCard from '../../components/dashboard/StatCard'
import { useAuth } from '../../hooks/useAuth'
import { useCentral } from '../../hooks/useCentral'

export default function ProfilePage() {
  const { adminProfile } = useAuth()
  const central = useCentral()

  return (
    <div className="saas-page-stack">
      <section className="admin-section-headline">
        <div>
          <span className="eyebrow">Perfil institucional</span>
          <h2>Datos de la central y lectura operativa actual</h2>
          <p>Vista compacta para revisar la identidad de la cabina, el estado de sesion y el pulso operativo general sin ruido visual.</p>
        </div>
      </section>

      <section className="admin-stats-grid">
        <StatCard label="Central" value={adminProfile?.fullName || adminProfile?.username || 'Central'} detail="Perfil institucional activo" icon="🏢" />
        <StatCard label="Telefono" value={adminProfile?.phone || 'Sin numero'} detail="Contacto visible en la central" icon="📞" />
        <StatCard label="Ultimo refresh" value={central.lastUpdatedAt || 'Sin lectura'} detail="Sincronizacion mostrada por el panel" icon="🕒" tone="neutral" />
        <StatCard label="Usuarios" value={`${central.managedUsers.length}`} detail="Cuentas visibles en la gestion" icon="👥" tone="success" />
      </section>

      <section className="settings-page-grid">
        <Card title="Identidad institucional" subtitle="Datos base de la central" className="saas-panel-dark">
          <div className="settings-stack">
            <div className="admin-detail-card">
              <span>Usuario</span>
              <strong>{adminProfile?.username || 'central'}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Nombre</span>
              <strong>{adminProfile?.fullName || 'Central Flash Go'}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Telefono</span>
              <strong>{adminProfile?.phone || 'Sin numero'}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Sesion</span>
              <strong>Activa</strong>
            </div>
          </div>
        </Card>

        <Card title="Pulso operativo" subtitle="Salud resumida de la central" className="saas-panel-dark">
          <div className="settings-stack">
            <div className="admin-detail-card">
              <span>Flota visible</span>
              <strong>{central.drivers.length}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Soporte abierto</span>
              <strong>{central.supportSummary.open}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Dispositivos</span>
              <strong>{central.allDevices.length}</strong>
            </div>
            <div className="admin-detail-card">
              <span>Offline</span>
              <strong>{central.offlineMapStatus.status}</strong>
            </div>
          </div>
        </Card>
      </section>
    </div>
  )
}
