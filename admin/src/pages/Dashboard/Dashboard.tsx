import { Navigate } from 'react-router-dom'
import { APP_ROUTES } from '../../utils/constants'

export default function Dashboard() {
  return <Navigate to={APP_ROUTES.overview} replace />
}
