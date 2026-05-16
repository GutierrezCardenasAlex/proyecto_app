import { Link } from 'react-router-dom'
import Card from '../../components/cards/Card'
import { APP_ROUTES } from '../../utils/constants'

type Props = {
  title?: string
  subtitle?: string
  showMonitoringLink?: boolean
}

export default function AccessDenied({
  title = 'No tienes permisos suficientes',
  subtitle = 'Esta vista requiere autenticacion valida y el nivel de acceso correcto.',
  showMonitoringLink = true,
}: Props) {
  return (
    <div className="access-denied-shell">
      <Card title={title} subtitle={subtitle} className="access-denied-card">
        <p className="subtitle">
          Por seguridad, la central bloquea cualquier vista protegida cuando la sesion no existe, vencio o no tiene el perfil autorizado.
        </p>
        <div className="access-denied-actions">
          <Link className="primary-button" to={APP_ROUTES.accessGate}>
            Abrir portal seguro
          </Link>
          {showMonitoringLink && (
            <Link className="secondary-button" to={APP_ROUTES.monitoringLogin}>
              Ir a monitoreo
            </Link>
          )}
        </div>
      </Card>
    </div>
  )
}
