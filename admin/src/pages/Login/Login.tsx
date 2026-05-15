import { useState } from 'react'
import Button from '../../components/common/Button'
import Card from '../../components/cards/Card'
import { loginAdmin, requestAdminOtp, verifyAdminOtp } from '../../services/authService'
import { DEFAULT_LOGIN } from '../../utils/constants'
import { useAuth } from '../../hooks/useAuth'

export default function Login() {
  const { setAuthenticatedSession, setAdminProfile } = useAuth()
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
      const payload = await loginAdmin(username, password)
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
      setAuthenticatedSession(payload.token, payload.admin)
    } catch (verifyError) {
      setError(verifyError instanceof Error ? verifyError.message : 'No se pudo validar el OTP.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <section className="hero-panel auth-card">
      <div>
        <p className="eyebrow">Central Flash Go</p>
        <h1>Centro ejecutivo de operacion, autorizacion y monitoreo institucional.</h1>
        <p className="subtitle">
          Ingresa con tu usuario y contrasena de central. Luego valida con el numero institucional para abrir el dashboard ejecutivo.
        </p>
        <div className="stats executive-auth-stats">
          <article className="stat-card">
            <strong>Acceso institucional</strong>
            <span>Usuario, contrasena y OTP de la central</span>
          </article>
          <article className="stat-card">
            <strong>Control total</strong>
            <span>Flota, soporte, dispositivos y promociones</span>
          </article>
        </div>
      </div>

      <Card className="auth-form">
        <label>
          <span>Usuario ejecutivo</span>
          <input value={username} onChange={(event) => setUsername(event.target.value)} />
        </label>

        <label>
          <span>Contrasena</span>
          <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} />
        </label>

        <label>
          <span>Numero institucional</span>
          <input value={phone} onChange={(event) => setPhone(event.target.value)} disabled={!credentialsVerified} />
        </label>

        {credentialsVerified && otpRequested && (
          <label>
            <span>OTP</span>
            <input value={otp} onChange={(event) => setOtp(event.target.value)} />
          </label>
        )}

        {otpFallback && <div className="error-box">OTP de respaldo para central: {otpFallback}</div>}

        <Button
          disabled={loading}
          onClick={
            !credentialsVerified ? handleCredentialLogin : otpRequested ? handleVerifyOtp : handleRequestOtp
          }
        >
          {loading
            ? 'Procesando...'
            : !credentialsVerified
              ? 'Validar credenciales'
              : otpRequested
                ? 'Ingresar a central'
                : 'Solicitar OTP institucional'}
        </Button>

        {credentialsVerified && !otpRequested && (
          <div className="success-box">Credenciales validadas. Ahora solicita el OTP del numero institucional para ingresar.</div>
        )}

        {credentialsVerified && otpRequested && (
          <Button variant="secondary" disabled={loading} onClick={handleRequestOtp}>
            Reenviar OTP
          </Button>
        )}

        {error && <div className="error-box">{error}</div>}
      </Card>
    </section>
  )
}
