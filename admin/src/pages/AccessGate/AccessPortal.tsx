import { Link } from 'react-router-dom'
import Button from '../../components/common/Button'
import Card from '../../components/cards/Card'
import { useAuth } from '../../hooks/useAuth'
import { APP_ROUTES } from '../../utils/constants'

export default function AccessPortal() {
  const { clearAccessGate } = useAuth()

  return (
    <section className="hero-panel auth-card">
      <div>
        <p className="eyebrow">Portal operativo desbloqueado</p>
        <h1>Elige el modulo al que deseas entrar.</h1>
        <p className="subtitle">
          Este selector funciona como una pantalla estilo cabina segura: cada ruta posterior queda limitada al nivel de permisos correspondiente.
        </p>
      </div>

      <div className="access-portal-grid">
        <Card title="Central ejecutiva" subtitle="Dashboard completo, autorizaciones, usuarios y configuracion." className="access-portal-card">
          <p className="subtitle">Requiere login institucional con usuario, contrasena y OTP antes de entrar.</p>
          <Link className="primary-button" to={APP_ROUTES.login}>
            Entrar a central
          </Link>
        </Card>

        <Card title="Monitoreo en vivo" subtitle="Vista restringida solo para mapa y seguimiento de flota." className="access-portal-card">
          <p className="subtitle">Permite abrir solo el mapa operativo. No expone CRUD, reportes ni configuracion.</p>
          <Link className="secondary-button" to={APP_ROUTES.monitoringLogin}>
            Entrar a monitoreo
          </Link>
        </Card>

        <div className="access-portal-footer">
          <Button variant="danger" onClick={clearAccessGate}>
            Cerrar portal seguro
          </Button>
        </div>
      </div>
    </section>
  )
}
