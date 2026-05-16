import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Button from '../../components/common/Button'
import Card from '../../components/cards/Card'
import { useAuth } from '../../hooks/useAuth'
import { verifyAccessGate } from '../../services/authService'
import { APP_ROUTES } from '../../utils/constants'

export default function AccessGate() {
  const navigate = useNavigate()
  const { setAccessGateToken } = useAuth()
  const [code, setCode] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleVerify() {
    setLoading(true)
    setError(null)
    try {
      const payload = await verifyAccessGate(code)
      setAccessGateToken(payload.gateToken)
      navigate(APP_ROUTES.accessHub, { replace: true })
    } catch (gateError) {
      setError(gateError instanceof Error ? gateError.message : 'No se pudo validar el codigo superAdmin.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <section className="hero-panel auth-card">
      <div>
        <p className="eyebrow">Acceso superAdmin</p>
        <h1>Ingresa tu codigo maestro para desbloquear el portal operativo.</h1>
        <p className="subtitle">
          Esta puerta funciona como una capa previa de seguridad. Solo despues de validar el codigo podras elegir central o monitoreo.
        </p>
        <div className="stats executive-auth-stats">
          <article className="stat-card">
            <strong>Filtro inicial</strong>
            <span>Bloquea accesos directos a URLs privadas si no pasaste primero por la puerta superAdmin.</span>
          </article>
          <article className="stat-card">
            <strong>Portal controlado</strong>
            <span>Despues del codigo se abre una vista tipo selector para entrar solo al modulo permitido.</span>
          </article>
        </div>
      </div>

      <Card className="auth-form">
        <label>
          <span>Codigo superAdmin</span>
          <input
            type="password"
            value={code}
            onChange={(event) => setCode(event.target.value)}
            placeholder="Ingresa el codigo maestro"
          />
        </label>

        {error && <div className="error-box">{error}</div>}

        <Button disabled={loading || code.trim().length < 5} onClick={handleVerify}>
          {loading ? 'Validando acceso...' : 'Abrir portal seguro'}
        </Button>
      </Card>
    </section>
  )
}
