import Button from '../common/Button'
import Card from '../cards/Card'
import type { DeviceRow, UserSummary } from '../../types/admin'

type Props = {
  devices: DeviceRow[]
  onLoadHistory: (user: UserSummary) => Promise<void>
  onAuthorize: (deviceId: number) => Promise<void>
  onReplace: (deviceId: number) => Promise<void>
  onBlock: (deviceId: number) => Promise<void>
}

export default function DevicesPanel({ devices, onLoadHistory, onAuthorize, onReplace, onBlock }: Props) {
  return (
    <Card title="Dispositivos registrados" subtitle={`${devices.length} en total`} className="devices-panel">
      <div className="table-wrapper">
        <table className="devices-table">
          <thead>
            <tr>
              <th>Usuario</th>
              <th>Rol</th>
              <th>Equipo</th>
              <th>Estado</th>
              <th>Central</th>
              <th>Accion</th>
            </tr>
          </thead>
          <tbody>
            {devices.map((device) => (
              <tr key={device.id}>
                <td>
                  <strong>{device.full_name || 'Sin nombre'}</strong>
                  <div>{device.phone}</div>
                </td>
                <td>{device.role}</td>
                <td>
                  <strong>{device.device_name || 'Equipo desconocido'}</strong>
                  <div>{device.platform || 'sin plataforma'}</div>
                </td>
                <td>
                  <span className={device.status === 'AUTORIZADO' ? 'status-pill success' : device.status === 'RECHAZADO' ? 'status-pill danger' : 'status-pill warning'}>
                    {device.status}
                  </span>
                </td>
                <td>{device.approved_by_name || 'Sin accion'}</td>
                <td>
                  <div className="action-row compact devices-actions">
                    <Button
                      variant="secondary"
                      className="table-action-button uniform-button"
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
                    <Button variant="success" className="table-action-button uniform-button" onClick={() => onAuthorize(device.id)}>
                      Autorizar
                    </Button>
                    <Button className="table-action-button uniform-button" onClick={() => onReplace(device.id)}>Reemplazar</Button>
                    <Button variant="danger" className="table-action-button uniform-button" onClick={() => onBlock(device.id)}>
                      Bloquear
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  )
}
