import { useState } from 'react'
import Button from '../../components/common/Button'
import Card from '../../components/cards/Card'
import { useAuth } from '../../hooks/useAuth'
import { MONITORING_CREDENTIALS } from '../../utils/constants'

export default function MonitoringLogin() {
  const { setMonitorAuthenticated } = useAuth()
  const [username, setUsername] = useState(MONITORING_CREDENTIALS.username)
  const [password, setPassword] = useState(MONITORING_CREDENTIALS.password)
  const [error, setError] = useState<string | null>(null)

  function handleLogin() {
    if (username === MONITORING_CREDENTIALS.username && password === MONITORING_CREDENTIALS.password) {
      setMonitorAuthenticated(true)
      setError(null)
      return
    }
    setError('Las credenciales de monitoreo no son correctas.')
  }

  return (
    <section className="hero-panel auth-card">
      <div>
        <p className="eyebrow">Acceso de monitoreo</p>
        <h1>Vista restringida para seguimiento en vivo de la flota.</h1>
        <p className="subtitle">
          Este acceso solo permite visualizar el mapa operativo. No muestra las otras secciones de central ni permite cambiar pantallas.
        </p>
        <div className="stats executive-auth-stats">
          <article className="stat-card">
            <strong>Solo mapa en vivo</strong>
            <span>Seguimiento visual de conductores, estados y ultima telemetria.</span>
          </article>
          <article className="stat-card">
            <strong>Acceso limitado</strong>
            <span>Sin CRUD, sin reportes, sin configuracion y sin cambio de modulos.</span>
          </article>
        </div>
      </div>

      <Card className="auth-form">
        <label>
          <span>Usuario de monitoreo</span>
          <input value={username} onChange={(event) => setUsername(event.target.value)} />
        </label>

        <label>
          <span>Contrasena</span>
          <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} />
        </label>

        {error && <div className="error-box">{error}</div>}

        <Button onClick={handleLogin}>Entrar a monitoreo</Button>
      </Card>
    </section>
  )
}
