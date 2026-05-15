import Button from '../common/Button'
import Card from '../cards/Card'
import type { DeviceRow, UserSummary } from '../../types/admin'

type Props = {
  user: UserSummary | null
  phoneDraft: string
  history: DeviceRow[]
  loading: boolean
  onPhoneChange: (value: string) => void
  onSavePhone: () => Promise<void>
  onAuthorizeDevice: (deviceId: number) => Promise<void>
  onReplaceDevice: (deviceId: number) => Promise<void>
  onBlockDevice: (deviceId: number) => Promise<void>
}

export default function UserHistoryPanel({
  user,
  phoneDraft,
  history,
  loading,
  onPhoneChange,
  onSavePhone,
  onAuthorizeDevice,
  onReplaceDevice,
  onBlockDevice,
}: Props) {
  if (!user) {
    return null
  }

  return (
    <Card title="Historial por usuario" subtitle={`${user.full_name || user.phone} · ${user.phone}`} className="devices-panel">
      <div className="phone-change-card">
        <div>
          <strong>Cambiar telefono autorizado</strong>
          <p>La central puede mover esta cuenta a un nuevo numero. El numero viejo queda libre y la cuenta se mantiene.</p>
        </div>
        <div className="phone-change-form">
          <input value={phoneDraft} onChange={(event) => onPhoneChange(event.target.value)} placeholder="+591..." />
          <Button onClick={() => void onSavePhone()} disabled={loading}>
            Guardar telefono
          </Button>
        </div>
      </div>

      <div className="list">
        {history.map((device) => (
          <article key={device.id} className="list-card stack-card">
            <div>
              <strong>{device.device_name || 'Equipo desconocido'}</strong>
              <p>{device.platform || 'sin plataforma'} · {device.device_identifier}</p>
              <p>Estado: {device.status}</p>
              <p>Ultimo acceso: {device.last_login_at || 'sin registros'}</p>
              <p>Central: {device.approved_by_name || 'sin accion'}</p>
            </div>
            <div className="action-row">
              <Button onClick={() => void onReplaceDevice(device.id)}>Autorizar este equipo</Button>
              <Button variant="secondary" onClick={() => void onAuthorizeDevice(device.id)}>
                Solo autorizar
              </Button>
              <Button variant="danger" onClick={() => void onBlockDevice(device.id)}>
                Bloquear
              </Button>
            </div>
          </article>
        ))}
      </div>
    </Card>
  )
}
