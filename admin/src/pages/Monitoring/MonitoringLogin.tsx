import { useState } from 'react'
import Button from '../../components/common/Button'
import Card from '../../components/cards/Card'
import { adminService } from '../../services/adminService'
import { loginMonitor } from '../../services/authService'
import { useAuth } from '../../hooks/useAuth'

export default function MonitoringLogin() {
  const { setAuthenticatedSession } = useAuth()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleLogin() {
    setLoading(true)
    setError(null)
    try {
      const payload = await loginMonitor(username.trim(), password)
      await adminService.getLiveDrivers(payload.token)
      setAuthenticatedSession(payload.token, payload.admin, 'monitor')
    } catch (loginError) {
      setError(loginError instanceof Error ? loginError.message : 'No se pudo abrir la sesion de monitoreo.')
    } finally {
      setLoading(false)
    }
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
          <input value={username} onChange={(event) => setUsername(event.target.value)} autoComplete="username" />
        </label>

        <label>
          <span>Contrasena</span>
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            autoComplete="current-password"
          />
        </label>

        {error && <div className="error-box">{error}</div>}

        <Button disabled={loading || username.trim().length < 3 || password.length < 8} onClick={handleLogin}>
          {loading ? 'Validando acceso...' : 'Entrar a monitoreo'}
        </Button>
      </Card>
    </section>
  )
}
