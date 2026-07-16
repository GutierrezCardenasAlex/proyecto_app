import Button from '../common/Button'
import Card from '../cards/Card'
import type { DeviceRow, PendingDriverAccessRow, PromoSettings, SupportReport, Trip } from '../../types/admin'
import { formatDateTime } from '../../utils/helpers'

type Props = {
  promoSettings: PromoSettings
  trips: Trip[]
  pendingDrivers: PendingDriverAccessRow[]
  pendingDevices: DeviceRow[]
  loading: boolean
  driverAccessNote: string
  supportReports: SupportReport[]
  notificationAudience: 'all' | 'passengers' | 'drivers' | 'user'
  notificationPhone: string
  notificationTitle: string
  notificationMessage: string
  notificationKind: 'nuevo' | 'importante' | 'sistema'
  onDriverAccessNoteChange: (value: string) => void
  onUpdatePromoStatus: (enabled: boolean) => Promise<void>
  onUpdateDriverAccess: (driverId: string, status: 'AUTORIZADO' | 'RECHAZADO', note?: string) => Promise<void>
  onUpdateDeviceStatus: (deviceId: number, status: 'AUTORIZADO' | 'RECHAZADO') => Promise<void>
  onLoadHistory: (user: { user_id: string; phone: string; full_name?: string | null; role?: string }) => Promise<void>
  onNotificationAudienceChange: (value: 'all' | 'passengers' | 'drivers' | 'user') => void
  onNotificationPhoneChange: (value: string) => void
  onNotificationTitleChange: (value: string) => void
  onNotificationMessageChange: (value: string) => void
  onNotificationKindChange: (value: 'nuevo' | 'importante' | 'sistema') => void
  onSendNotification: () => Promise<void>
}

export default function OverviewSections(props: Props) {
  return (
    <section className="content-grid">
      <div className="side-column side-column-full">
        <Card title="Promociones RAPIGO" subtitle={props.promoSettings.enabled ? 'Activa' : 'Pausada'}>
          <article className="list-card stack-card promo-card">
            <div>
              <strong>{props.promoSettings.enabled ? 'Promo habilitada' : 'Promo detenida'}</strong>
              <p>
                Cada {props.promoSettings.cycleLength} viajes pagados desbloquean {props.promoSettings.rewardCredits} viaje gratis.
              </p>
            </div>
            <div className="action-row">
              <Button disabled={props.loading || props.promoSettings.enabled} onClick={() => void props.onUpdatePromoStatus(true)}>
                Activar promo
              </Button>
              <Button variant="secondary" disabled={props.loading || !props.promoSettings.enabled} onClick={() => void props.onUpdatePromoStatus(false)}>
                Pausar promo
              </Button>
            </div>
          </article>
        </Card>

        <Card title="Notificaciones central" subtitle={props.notificationAudience === 'user' ? 'Usuario puntual' : 'Difusion'}>
          <article className="list-card stack-card promo-card">
            <div className="phone-change-form">
              <select value={props.notificationAudience} onChange={(event) => props.onNotificationAudienceChange(event.target.value as 'all' | 'passengers' | 'drivers' | 'user')}>
                <option value="all">Todos</option>
                <option value="passengers">Solo pasajeros</option>
                <option value="drivers">Solo conductores</option>
                <option value="user">Usuario por telefono</option>
              </select>
              <select value={props.notificationKind} onChange={(event) => props.onNotificationKindChange(event.target.value as 'nuevo' | 'importante' | 'sistema')}>
                <option value="nuevo">Nuevo</option>
                <option value="importante">Importante</option>
                <option value="sistema">Sistema</option>
              </select>
              {props.notificationAudience === 'user' && (
                <input value={props.notificationPhone} onChange={(event) => props.onNotificationPhoneChange(event.target.value)} placeholder="+591..." />
              )}
              <input value={props.notificationTitle} onChange={(event) => props.onNotificationTitleChange(event.target.value)} placeholder="Titulo de la notificacion" />
              <textarea className="note-input" value={props.notificationMessage} onChange={(event) => props.onNotificationMessageChange(event.target.value)} placeholder="Mensaje para la app del pasajero o conductor" />
              <Button onClick={() => void props.onSendNotification()} disabled={props.loading}>
                {props.loading ? 'Enviando...' : 'Enviar notificacion'}
              </Button>
            </div>
          </article>
        </Card>

        <Card title="Conductores por autorizar" subtitle={`${props.pendingDrivers.length} pendientes`}>
          <div className="list">
            {props.pendingDrivers.length === 0 && <article className="list-card">Sin conductores pendientes.</article>}
            {props.pendingDrivers.map((driver) => (
              <article key={driver.id} className="list-card stack-card">
                <div>
                  <div className="performance-heading">
                    <strong>{driver.full_name || driver.phone}</strong>
                    <span className={driver.access_status === 'AUTORIZADO' ? 'status-pill success' : driver.access_status === 'RECHAZADO' ? 'status-pill danger' : 'status-pill warning'}>
                      {driver.access_status}
                    </span>
                  </div>
                  <p>conductor · {driver.phone}</p>
                  <p>Registrado: {formatDateTime(driver.created_at)} · Actualizado: {formatDateTime(driver.updated_at)}</p>
                  <p>{driver.email || 'Sin email'} · {driver.address || 'Sin direccion'}</p>
                  <p>
                    Licencia: {driver.license_number || 'pendiente'} · Categoria {driver.license_category || 'sin categoria'} · Emision{' '}
                    {driver.license_issue_date || 'pendiente'} · Vence {driver.license_expiry_date || 'pendiente'}
                  </p>
                  <p>
                    Vehiculo: {driver.vehicle_type || 'sin tipo'} · {driver.plate || 'sin placa'} ·{' '}
                    {[driver.brand, driver.model, driver.color, driver.year].filter(Boolean).join(' ') || 'datos incompletos'}
                  </p>
                  {driver.missing_fields?.length ? (
                    <p className="muted-text">Falta verificar: {driver.missing_fields.join(', ')}</p>
                  ) : (
                    <p className="success-text">Expediente completo para autorizar.</p>
                  )}
                </div>
                <div className="stack-actions">
                  <textarea value={props.driverAccessNote} onChange={(event) => props.onDriverAccessNoteChange(event.target.value)} placeholder="Nota opcional para central" className="note-input" />
                  <div className="action-row">
                    <Button variant="success" disabled={driver.verification_ready === false} onClick={() => void props.onUpdateDriverAccess(driver.id, 'AUTORIZADO', props.driverAccessNote)}>
                      Autorizar conductor
                    </Button>
                    <Button variant="danger" onClick={() => void props.onUpdateDriverAccess(driver.id, 'RECHAZADO', props.driverAccessNote)}>
                      Rechazar
                    </Button>
                    <Button
                      variant="secondary"
                      onClick={() =>
                        void props.onLoadHistory({
                          user_id: driver.user_id,
                          phone: driver.phone,
                          full_name: driver.full_name,
                          role: 'driver',
                        })
                      }
                    >
                      Ver usuario
                    </Button>
                  </div>
                </div>
              </article>
            ))}
          </div>
        </Card>

        <Card title="Solicitudes de dispositivos" subtitle={`${props.pendingDevices.length} pendientes`}>
          <div className="list">
            {props.pendingDevices.length === 0 && <article className="list-card">Sin solicitudes pendientes.</article>}
            {props.pendingDevices.map((device) => (
              <article key={device.id} className="list-card stack-card">
                <div>
                  <div className="performance-heading">
                    <strong>{device.full_name || device.phone}</strong>
                    <span className={device.status === 'AUTORIZADO' ? 'status-pill success' : device.status === 'RECHAZADO' ? 'status-pill danger' : 'status-pill warning'}>
                      {device.status}
                    </span>
                  </div>
                  <p>{device.role} · {device.phone}</p>
                  <p>{device.device_name || 'Equipo desconocido'}</p>
                  <p>{device.platform || 'sin plataforma'} · {device.device_identifier}</p>
                </div>
                <div className="action-row">
                  <Button variant="success" onClick={() => void props.onUpdateDeviceStatus(device.id, 'AUTORIZADO')}>
                    Aprobar
                  </Button>
                  <Button variant="danger" onClick={() => void props.onUpdateDeviceStatus(device.id, 'RECHAZADO')}>
                    Rechazar
                  </Button>
                  <Button
                    variant="secondary"
                    onClick={() =>
                      void props.onLoadHistory({
                        user_id: device.user_id,
                        phone: device.phone,
                        full_name: device.full_name,
                        role: device.role,
                      })
                    }
                  >
                    Ver historial
                  </Button>
                </div>
              </article>
            ))}
          </div>
        </Card>

        <Card title="Viajes activos" subtitle={`${props.trips.length} visibles`}>
          <div className="list">
            {props.trips.map((trip) => (
              <article key={trip.id} className="list-card">
                <div>
                  <strong>{trip.id.slice(0, 8)}</strong>
                  <p>{trip.status}</p>
                </div>
                <span>{trip.driver_id ? 'Asignado' : 'Buscando'}</span>
              </article>
            ))}
          </div>
        </Card>

        <Card title="Mesa de soporte rapido" subtitle={`${props.supportReports.filter((report) => report.status === 'ABIERTO').length} abiertos`}>
          <div className="list">
            {props.supportReports.slice(0, 6).map((report) => (
              <article key={report.id} className="list-card">
                <div>
                  <strong>{report.full_name || report.phone}</strong>
                  <p>{report.category}</p>
                </div>
                <span className={report.status === 'ABIERTO' ? 'status-pill warning subtle' : 'status-pill success subtle'}>{report.status}</span>
              </article>
            ))}
          </div>
        </Card>
      </div>
    </section>
  )
}
