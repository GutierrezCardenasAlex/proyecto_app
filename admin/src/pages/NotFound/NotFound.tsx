import { Link } from 'react-router-dom'
import Card from '../../components/cards/Card'
import { APP_ROUTES } from '../../utils/constants'

export default function NotFound() {
  return (
    <Card title="Vista no encontrada" subtitle="La ruta solicitada no existe en esta central.">
      <p className="subtitle">Vuelve al inicio del panel y continua desde una de las rutas disponibles.</p>
      <Link className="primary-button" to={APP_ROUTES.overview}>
        Ir al inicio
      </Link>
    </Card>
  )
}
