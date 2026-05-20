import Button from '../common/Button'
import Card from '../cards/Card'
import type { DeviceRow, UserSummary } from '../../types/admin'
import { formatDateTime } from '../../utils/helpers'

type Props = {
  devices: DeviceRow[]
  onLoadHistory: (user: UserSummary) => Promise<void>
  onAuthorize: (deviceId: number) => Promise<void>
  onReplace: (deviceId: number) => Promise<void>
  onBlock: (deviceId: number) => Promise<void>
  onManageUser: (userId: string) => void
}

function getDeviceTone(status: DeviceRow['status']) {
  if (status === 'AUTORIZADO') return 'success'
  if (status === 'RECHAZADO') return 'danger'
  return 'warning'
}

export default function DevicesPanel({ devices, onLoadHistory, onAuthorize, onReplace, onBlock, onManageUser }: Props) {
  return (
    <Card title="Dispositivos registrados" subtitle={`${devices.length} equipos visibles con trazabilidad y gobierno centralizado`} className="devices-panel">
      {!devices.length ? (
        <div className="admin-empty-state">
          <strong>No hay dispositivos registrados</strong>
          <p>Cuando existan accesos de equipos apareceran aqui con autorizacion, bloqueo, reemplazo e historial.</p>
        </div>
      ) : (
        <div className="device-collection">
          {devices.map((device) => (
            <article key={device.id} className="device-card">
              <div className="device-card__head">
                <div>
                  <span className="eyebrow">Usuario vinculado</span>
                  <h3>{device.full_name || 'Usuario sin nombre'}</h3>
                  <p>{device.phone}</p>
                </div>
                <span className={`status-pill ${getDeviceTone(device.status)}`}>{device.status}</span>
              </div>

              <div className="device-card__meta">
                <div className="device-card__meta-item">
                  <span>Rol</span>
                  <strong>{device.role === 'driver' ? 'Conductor' : 'Pasajero'}</strong>
                </div>
                <div className="device-card__meta-item">
                  <span>Equipo</span>
                  <strong>{device.device_name || 'Equipo desconocido'}</strong>
                </div>
                <div className="device-card__meta-item">
                  <span>Plataforma</span>
                  <strong>{device.platform || 'Sin plataforma'}</strong>
                </div>
                <div className="device-card__meta-item">
                  <span>Central</span>
                  <strong>{device.approved_by_name || 'Sin accion'}</strong>
                </div>
                <div className="device-card__meta-item">
                  <span>Ultimo acceso</span>
                  <strong>{formatDateTime(device.last_login_at, 'Sin acceso')}</strong>
                </div>
                <div className="device-card__meta-item">
                  <span>Autorizado</span>
                  <strong>{formatDateTime(device.approved_at, 'Pendiente')}</strong>
                </div>
              </div>

              <div className="device-card__footer">
                <div className="device-card__identifier">
                  <span>Identificador</span>
                  <strong>{device.device_identifier}</strong>
                </div>

                <div className="device-actions-grid">
                  <Button variant="secondary" className="uniform-button" onClick={() => onManageUser(device.user_id)}>
                    Gestionar usuario
                  </Button>
                  <Button
                    variant="secondary"
                    className="uniform-button"
                    onClick={() =>
                      onLoadHistory({
                        user_id: device.user_id,
                        phone: device.phone,
                        full_name: device.full_name,
                        role: device.role,
                      })
                    }
                  >
                    Historial
                  </Button>
                  <Button variant="success" className="uniform-button" onClick={() => onAuthorize(device.id)}>
                    Autorizar
                  </Button>
                  <Button className="uniform-button" onClick={() => onReplace(device.id)}>
                    Reemplazar
                  </Button>
                  <Button variant="danger" className="uniform-button" onClick={() => onBlock(device.id)}>
                    Bloquear
                  </Button>
                </div>
              </div>
            </article>
          ))}
        </div>
      )}
    </Card>
  )
}
