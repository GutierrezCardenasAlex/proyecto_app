import Button from '../common/Button'
import Card from '../cards/Card'
import type { DriverPerformanceResponse, DriverTripsResponse, PerformanceRange } from '../../types/admin'
import { formatDateTime, getInitials } from '../../utils/helpers'

type Props = {
  performanceRange: PerformanceRange
  driverPerformance: DriverPerformanceResponse
  selectedDriverTrips: DriverTripsResponse | null
  loading: boolean
  onChangeRange: (range: PerformanceRange) => Promise<void>
  onLoadTrips: (driverId: string) => Promise<void>
  onCloseTrips: () => void
}

export default function StatsPanel({
  performanceRange,
  driverPerformance,
  selectedDriverTrips,
  loading,
  onChangeRange,
  onLoadTrips,
  onCloseTrips,
}: Props) {
  const topDriver = driverPerformance.rows[0] ?? null

  return (
    <>
      <Card
        title="Estadistica de conductores"
        subtitle={performanceRange === 'day' ? 'Hoy' : performanceRange === 'week' ? '7 dias' : '30 dias'}
      >
        <article className="list-card stack-card promo-card">
          <div className="filter-chip-row">
            {(['day', 'week', 'month'] as PerformanceRange[]).map((range) => (
              <button
                key={range}
                className={performanceRange === range ? 'filter-chip active' : 'filter-chip'}
                disabled={loading}
                onClick={() => void onChangeRange(range)}
              >
                {range === 'day' ? 'Dia' : range === 'week' ? 'Semana' : 'Mes'}
              </button>
            ))}
          </div>

          <div className="mini-stats-grid">
            <div className="mini-stat-card">
              <span>Viajes del periodo</span>
              <strong>{driverPerformance.summary.totalTrips}</strong>
            </div>
            <div className="mini-stat-card">
              <span>Completados</span>
              <strong>{driverPerformance.summary.completedTrips}</strong>
            </div>
            <div className="mini-stat-card">
              <span>Promocionales</span>
              <strong>{driverPerformance.summary.promoTrips}</strong>
            </div>
            <div className="mini-stat-card">
              <span>Choferes activos</span>
              <strong>{driverPerformance.summary.activeDrivers}</strong>
            </div>
          </div>

          {topDriver && topDriver.totalTrips > 0 && (
            <div className="highlight-card">
              <div>
                <span className="status-pill success">Top del periodo</span>
                <strong>{topDriver.fullName || topDriver.phone}</strong>
                <p>
                  {topDriver.completedTrips} viajes completados · {topDriver.tripsThisWeek} esta semana · {topDriver.rating.toFixed(1)} estrellas
                </p>
              </div>
              <div className="stack-actions">
                <span className={topDriver.isAvailable ? 'status-pill success' : 'status-pill danger'}>
                  {topDriver.isAvailable ? 'Disponible' : 'No disponible'}
                </span>
              </div>
            </div>
          )}

          <div className="performance-table-shell">
            <div className="table-wrapper">
              <table className="driver-stats-table">
                <thead>
                  <tr>
                    <th>Conductor</th>
                    <th>Estado</th>
                    <th>Viajes</th>
                    <th>Calificacion</th>
                    <th>Eficiencia</th>
                    <th className="table-actions-cell">Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {driverPerformance.rows.length === 0 && (
                    <tr>
                      <td colSpan={6}>
                        <div className="empty-table-state">Sin viajes para este periodo.</div>
                      </td>
                    </tr>
                  )}
                  {driverPerformance.rows.map((row, index) => {
                    const completionRate = row.totalTrips > 0 ? Math.round((row.completedTrips / row.totalTrips) * 100) : 0
                    return (
                      <tr key={row.driverId} className="driver-table-row">
                        <td>
                          <div className="driver-identity">
                            <div className="driver-avatar">{getInitials(row.fullName || row.phone)}</div>
                            <div>
                              <p className="driver-name">{row.fullName || row.phone}</p>
                              <p className="driver-meta">ID #{index + 1} · {row.phone}</p>
                            </div>
                          </div>
                        </td>
                        <td>
                          <span className={row.isAvailable ? 'status-pill success' : 'status-pill warning'}>
                            {row.isAvailable ? 'Activo' : 'En descanso'}
                          </span>
                        </td>
                        <td>
                          <p className="table-primary">{row.totalTrips}</p>
                          <p className="table-secondary">{row.tripsThisWeek} esta semana</p>
                        </td>
                        <td>
                          <div className="rating-cell">
                            <span className="rating-star">★</span>
                            <span className="table-primary">{row.rating > 0 ? row.rating.toFixed(1) : '0.0'}</span>
                          </div>
                        </td>
                        <td>
                          <p className="table-primary">{completionRate}%</p>
                          <p className="table-secondary">{row.promoTrips} promo · {row.cancelledTrips} cancelados</p>
                        </td>
                        <td className="table-actions-cell">
                          <Button variant="secondary" className="table-action-button" onClick={() => void onLoadTrips(row.driverId)}>
                            Ver historial
                          </Button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </article>
      </Card>

      {selectedDriverTrips && (
        <Card
          title="Detalle del conductor"
          subtitle={`${selectedDriverTrips.driver.fullName || selectedDriverTrips.driver.phone} · ${selectedDriverTrips.trips.length} viajes`}
          className="devices-panel"
        >
          <div className="driver-detail-summary">
            <div className="mini-stat-card">
              <span>Conductor</span>
              <strong>{selectedDriverTrips.driver.fullName || 'Sin nombre'}</strong>
              <p>{selectedDriverTrips.driver.phone}</p>
            </div>
            <div className="mini-stat-card">
              <span>Estado</span>
              <strong>{selectedDriverTrips.driver.status}</strong>
              <p>{selectedDriverTrips.driver.isAvailable ? 'Disponible' : 'No disponible'}</p>
            </div>
            <div className="mini-stat-card">
              <span>Periodo</span>
              <strong>{selectedDriverTrips.range === 'all' ? 'Todos' : selectedDriverTrips.range}</strong>
              <p>Incluye promociones y todos los viajes del filtro</p>
            </div>
            <div className="mini-stat-card">
              <span>Promos</span>
              <strong>{selectedDriverTrips.trips.filter((trip) => trip.promotionalTrip).length}</strong>
              <p>Viajes promocionales detectados</p>
            </div>
          </div>

          <div className="list">
            {selectedDriverTrips.trips.map((trip) => (
              <article key={trip.id} className="support-card">
                <div className="support-card-top">
                  <div>
                    <strong>{trip.passengerName || 'Pasajero Flash Go'}</strong>
                    <p>{trip.passengerPhone || 'Sin telefono visible'} · viaje {trip.id.slice(0, 8)}</p>
                  </div>
                  <div className="support-badges">
                    <span className={trip.promotionalTrip ? 'status-pill success subtle' : 'status-pill warning subtle'}>
                      {trip.promotionalTrip ? 'Promo' : 'Normal'}
                    </span>
                    <span className={trip.status === 'completed' ? 'status-pill success subtle' : trip.status === 'cancelled' ? 'status-pill danger subtle' : 'status-pill warning subtle'}>
                      {trip.status}
                    </span>
                  </div>
                </div>
                <div className="driver-trip-grid">
                  <div className="performance-metric">
                    <span>Recojo</span>
                    <strong>
                      {trip.pickupLat != null && trip.pickupLng != null ? `${trip.pickupLat.toFixed(5)}, ${trip.pickupLng.toFixed(5)}` : 'Sin coordenada'}
                    </strong>
                  </div>
                  <div className="performance-metric">
                    <span>Destino</span>
                    <strong>
                      {trip.destinationLat != null && trip.destinationLng != null ? `${trip.destinationLat.toFixed(5)}, ${trip.destinationLng.toFixed(5)}` : 'Sin coordenada'}
                    </strong>
                  </div>
                  <div className="performance-metric">
                    <span>Solicitado</span>
                    <strong>{formatDateTime(trip.requestedAt)}</strong>
                  </div>
                  <div className="performance-metric">
                    <span>Finalizado</span>
                    <strong>{formatDateTime(trip.completedAt || trip.cancelledAt, 'En proceso')}</strong>
                  </div>
                </div>
              </article>
            ))}
          </div>

          <div className="action-row">
            <Button variant="secondary" onClick={onCloseTrips}>
              Cerrar detalle
            </Button>
          </div>
        </Card>
      )}
    </>
  )
}
