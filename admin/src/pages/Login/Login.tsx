import { useState } from 'react'
import Button from '../../components/common/Button'
import Card from '../../components/cards/Card'
import { loginAdmin, requestAdminOtp, verifyAdminOtp } from '../../services/authService'
import { DEFAULT_LOGIN } from '../../utils/constants'
import { useAuth } from '../../hooks/useAuth'

export default function Login() {
  const { gateToken, setAuthenticatedSession, setAdminProfile } = useAuth()
  const [username, setUsername] = useState(DEFAULT_LOGIN.username)
  const [password, setPassword] = useState(DEFAULT_LOGIN.password)
  const [phone, setPhone] = useState(DEFAULT_LOGIN.phone)
  const [otp, setOtp] = useState(DEFAULT_LOGIN.otp)
  const [otpRequested, setOtpRequested] = useState(false)
  const [credentialsVerified, setCredentialsVerified] = useState(false)
  const [otpFallback, setOtpFallback] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleCredentialLogin() {
    setLoading(true)
    setError(null)
    try {
      const payload = await loginAdmin(username, password, gateToken)
      setCredentialsVerified(true)
      setAdminProfile(payload.admin)
      setPhone(payload.admin.phone || phone)
      setOtpRequested(false)
      setOtpFallback(null)
    } catch (loginError) {
      setError(loginError instanceof Error ? loginError.message : 'No se pudieron validar las credenciales.')
    } finally {
      setLoading(false)
    }
  }

  async function handleRequestOtp() {
    setLoading(true)
    setError(null)
    try {
      const payload = await requestAdminOtp(phone)
      setOtpRequested(true)
      if (!payload.smsDelivered && payload.otp) {
        setOtp(payload.otp)
        setOtpFallback(payload.otp)
        setError(`No se pudo enviar SMS. Usa este OTP de respaldo: ${payload.otp}`)
      } else {
        setOtpFallback(null)
      }
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'No se pudo solicitar el OTP.')
    } finally {
      setLoading(false)
    }
  }

  async function handleVerifyOtp() {
    setLoading(true)
    setError(null)
    try {
      const payload = await verifyAdminOtp(phone, otp)
      setAuthenticatedSession(payload.token, payload.admin, 'admin')
    } catch (verifyError) {
      setError(verifyError instanceof Error ? verifyError.message : 'No se pudo validar el OTP.')
    } finally {
      setLoading(false)
    }
  }

  const canValidateCredentials =
    username.trim().length >= 3 && password.trim().length >= 8

  return (
    <section className="hero-panel auth-card">
      <div>
        <p className="eyebrow">Central RAPIGO</p>
        <h1>Centro ejecutivo de operacion, autorizacion y monitoreo institucional.</h1>
        <p className="subtitle">
          La puerta superAdmin ya fue validada. Ahora autentica tu usuario de central y confirma con el numero institucional para abrir el dashboard.
        </p>
        <div className="stats executive-auth-stats">
          <article className="stat-card">
            <strong>Triple control</strong>
            <span>Puerta superAdmin, credenciales de central y OTP institucional para cerrar puertas no autorizadas.</span>
          </article>
          <article className="stat-card">
            <strong>Sesion obligatoria</strong>
            <span>Si la sesion falta o vence, la central bloquea vistas protegidas y expulsa el acceso.</span>
          </article>
        </div>
      </div>

      <Card className="auth-form">
        <label>
          <span>Usuario central</span>
          <input value={username} onChange={(event) => setUsername(event.target.value)} autoComplete="username" />
        </label>

        <label>
          <span>Contrasena</span>
          <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" />
        </label>

        {credentialsVerified && (
          <label>
            <span>Numero institucional</span>
            <input value={phone} onChange={(event) => setPhone(event.target.value)} />
          </label>
        )}

        {otpRequested && (
          <label>
            <span>OTP institucional</span>
            <input value={otp} onChange={(event) => setOtp(event.target.value)} />
          </label>
        )}

        {error && <div className="error-box">{error}</div>}

        {otpFallback && <div className="success-box">OTP de respaldo listo para usar: {otpFallback}</div>}

        <Button
          disabled={
            loading ||
            (!credentialsVerified && !canValidateCredentials) ||
            (credentialsVerified && !otpRequested && phone.trim().length < 8) ||
            (credentialsVerified && otpRequested && otp.trim().length < 6)
          }
          onClick={!credentialsVerified ? handleCredentialLogin : otpRequested ? handleVerifyOtp : handleRequestOtp}
        >
          {loading
            ? 'Procesando...'
            : !credentialsVerified
              ? 'Validar superAdmin y credenciales'
              : otpRequested
                ? 'Ingresar a central'
                : 'Solicitar OTP institucional'}
        </Button>

        {credentialsVerified && !otpRequested && (
          <div className="success-box">Acceso superAdmin y credenciales validados. Ahora solicita el OTP institucional para ingresar.</div>
        )}

        {credentialsVerified && otpRequested && (
          <Button variant="secondary" disabled={loading} onClick={handleRequestOtp}>
            Reenviar OTP
          </Button>
        )}
      </Card>
    </section>
  )
}
