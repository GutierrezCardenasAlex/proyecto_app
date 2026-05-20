import { useMemo, useState } from 'react'
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

const currencyFormatter = new Intl.NumberFormat('es-BO', {
  style: 'currency',
  currency: 'BOB',
  maximumFractionDigits: 0,
})

const periodLabelMap: Record<PerformanceRange, string> = {
  day: 'Dia',
  week: 'Semana',
  month: 'Mes',
}

function formatCurrency(value: number) {
  return currencyFormatter.format(value || 0)
}

function normalizeDateFilter(value: string, endOfDay = false) {
  if (!value) return null
  const parsed = new Date(`${value}T${endOfDay ? '23:59:59' : '00:00:00'}`)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

export default function DriverReportsPanel({
  performanceRange,
  driverPerformance,
  selectedDriverTrips,
  loading,
  onChangeRange,
  onLoadTrips,
  onCloseTrips,
}: Props) {
  const [search, setSearch] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')

  const filteredRows = useMemo(() => {
    const query = search.trim().toLowerCase()
    const startDate = normalizeDateFilter(dateFrom)
    const endDate = normalizeDateFilter(dateTo, true)

    return driverPerformance.rows.filter((row) => {
      const haystack = `${row.fullName ?? ''} ${row.phone} ${row.driverStatus}`.toLowerCase()
      const matchesSearch = !query || haystack.includes(query)

      const rowDate = row.lastTripAt ? new Date(row.lastTripAt) : null
      const hasValidDate = rowDate && !Number.isNaN(rowDate.getTime())
      const matchesFrom = !startDate || (hasValidDate ? rowDate >= startDate : false)
      const matchesTo = !endDate || (hasValidDate ? rowDate <= endDate : false)

      return matchesSearch && matchesFrom && matchesTo
    })
  }, [dateFrom, dateTo, driverPerformance.rows, search])

  const chartRows = useMemo(
    () =>
      [...filteredRows]
        .sort((a, b) => b.completedTrips - a.completedTrips || b.revenue - a.revenue)
        .slice(0, 6),
    [filteredRows],
  )

  const visibleSummary = useMemo(
    () => ({
      drivers: filteredRows.length,
      trips: filteredRows.reduce((acc, row) => acc + row.totalTrips, 0),
      completed: filteredRows.reduce((acc, row) => acc + row.completedTrips, 0),
      revenue: filteredRows.reduce((acc, row) => acc + row.revenue, 0),
    }),
    [filteredRows],
  )

  const selectedSummary = useMemo(() => {
    if (!selectedDriverTrips) return null
    const trips = selectedDriverTrips.trips
    return {
      total: trips.length,
      completed: trips.filter((trip) => trip.status.toUpperCase().includes('COMPLE')).length,
      cancelled: trips.filter((trip) => trip.status.toUpperCase().includes('CANCEL')).length,
      promo: trips.filter((trip) => trip.promotionalTrip).length,
      revenue: trips.reduce((acc, trip) => acc + Number(trip.fareAmount || 0), 0),
    }
  }, [selectedDriverTrips])

  const maxCompletedTrips = Math.max(...chartRows.map((row) => row.completedTrips), 1)

  function resetFilters() {
    setSearch('')
    setDateFrom('')
    setDateTo('')
  }

  function handleExportPdf() {
    if (typeof window === 'undefined') return

    const reportRows = filteredRows
      .map(
        (row) => `
          <tr>
            <td>${row.fullName || row.phone}</td>
            <td>${row.phone}</td>
            <td>${row.totalTrips}</td>
            <td>${row.completedTrips}</td>
            <td>${row.cancelledTrips}</td>
            <td>${formatCurrency(row.revenue)}</td>
            <td>${formatDateTime(row.lastTripAt, 'Sin viaje visible')}</td>
          </tr>
        `,
      )
      .join('')

    const selectedTripsMarkup = selectedDriverTrips
      ? `
        <h2>Detalle filtrado: ${selectedDriverTrips.driver.fullName || selectedDriverTrips.driver.phone}</h2>
        <table>
          <thead>
            <tr>
              <th>Viaje</th>
              <th>Estado</th>
              <th>Pasajero</th>
              <th>Monto</th>
              <th>Fecha</th>
            </tr>
          </thead>
          <tbody>
            ${selectedDriverTrips.trips
              .map(
                (trip) => `
                <tr>
                  <td>${trip.id.slice(0, 8)}</td>
                  <td>${trip.status}</td>
                  <td>${trip.passengerName || trip.passengerPhone || 'Sin dato'}</td>
                  <td>${formatCurrency(Number(trip.fareAmount || 0))}</td>
                  <td>${formatDateTime(trip.completedAt || trip.acceptedAt || trip.requestedAt, 'Sin fecha')}</td>
                </tr>
              `,
              )
              .join('')}
          </tbody>
        </table>
      `
      : ''

    const exportWindow = window.open('', '_blank', 'width=1200,height=900')
    if (!exportWindow) return

    exportWindow.document.write(`
      <html lang="es">
        <head>
          <title>Reporte de conductores</title>
          <style>
            body { font-family: Inter, Arial, sans-serif; margin: 32px; color: #111827; }
            h1, h2 { margin: 0 0 12px; }
            p { margin: 0 0 18px; color: #475569; }
            .summary { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin: 22px 0 30px; }
            .summary article { border: 1px solid #e2e8f0; border-radius: 14px; padding: 14px; background: #fff; }
            .summary span { display: block; color: #64748b; font-size: 12px; margin-bottom: 6px; }
            .summary strong { font-size: 20px; }
            table { width: 100%; border-collapse: collapse; margin: 14px 0 28px; }
            th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; }
            th { background: #f8fafc; color: #334155; }
            @media print { body { margin: 18px; } }
          </style>
        </head>
        <body>
          <h1>Reporte de conductores</h1>
          <p>Periodo: ${periodLabelMap[performanceRange]} · Generado: ${formatDateTime(driverPerformance.generatedAt, 'Ahora')}</p>
          <div class="summary">
            <article><span>Conductores visibles</span><strong>${visibleSummary.drivers}</strong></article>
            <article><span>Viajes visibles</span><strong>${visibleSummary.trips}</strong></article>
            <article><span>Completados</span><strong>${visibleSummary.completed}</strong></article>
            <article><span>Ingresos visibles</span><strong>${formatCurrency(visibleSummary.revenue)}</strong></article>
          </div>
          <table>
            <thead>
              <tr>
                <th>Conductor</th>
                <th>Contacto</th>
                <th>Viajes</th>
                <th>Completados</th>
                <th>Cancelados</th>
                <th>Ingresos</th>
                <th>Ultimo viaje</th>
              </tr>
            </thead>
            <tbody>${reportRows}</tbody>
          </table>
          ${selectedTripsMarkup}
        </body>
      </html>
    `)
    exportWindow.document.close()
    exportWindow.focus()
    window.setTimeout(() => {
      exportWindow.print()
    }, 250)
  }

  return (
    <Card
      title="Estadistica de conductores"
      subtitle="Grafica ejecutiva, busqueda por conductor y exportacion del reporte filtrado."
      className="saas-panel-dark"
      actions={
        <Button variant="secondary" onClick={handleExportPdf}>
          Exportar PDF
        </Button>
      }
    >
      <div className="driver-report-shell">
        <div className="driver-report-toolbar">
          <div className="driver-report-periods">
            {(['day', 'week', 'month'] as PerformanceRange[]).map((range) => (
              <button
                key={range}
                type="button"
                className={performanceRange === range ? 'admin-filter-tab active' : 'admin-filter-tab'}
                disabled={loading}
                onClick={() => void onChangeRange(range)}
              >
                {periodLabelMap[range]}
              </button>
            ))}
          </div>

          <label className="driver-report-search">
            <span>Buscar conductor</span>
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Nombre, telefono o estado"
            />
          </label>

          <div className="driver-report-dates">
            <label>
              <span>Desde</span>
              <input type="date" value={dateFrom} onChange={(event) => setDateFrom(event.target.value)} />
            </label>
            <label>
              <span>Hasta</span>
              <input type="date" value={dateTo} onChange={(event) => setDateTo(event.target.value)} />
            </label>
          </div>

          <Button variant="secondary" onClick={resetFilters}>
            Limpiar
          </Button>
        </div>

        <div className="driver-report-top-grid">
          <div className="driver-report-chart-card">
            <div className="driver-report-chart-head">
              <div>
                <strong>Grafica de viajes completados</strong>
                <span>Top visible del periodo seleccionado</span>
              </div>
              <small>{filteredRows.length} conductores visibles</small>
            </div>

            <div className="driver-report-chart">
              {chartRows.length === 0 && <div className="driver-report-empty">No hay conductores visibles con ese filtro.</div>}
              {chartRows.map((row) => (
                <article key={row.driverId} className="driver-report-bar-row">
                  <div className="driver-report-bar-copy">
                    <span className="driver-report-bar-avatar">{getInitials(row.fullName || row.phone)}</span>
                    <div>
                      <strong>{row.fullName || row.phone}</strong>
                      <small>{row.phone}</small>
                    </div>
                  </div>
                  <div className="driver-report-bar-track">
                    <div className="driver-report-bar-fill" style={{ width: `${Math.max((row.completedTrips / maxCompletedTrips) * 100, 8)}%` }} />
                  </div>
                  <div className="driver-report-bar-metrics">
                    <strong>{row.completedTrips}</strong>
                    <span>{formatCurrency(row.revenue)}</span>
                  </div>
                </article>
              ))}
            </div>
          </div>

          <div className="driver-report-kpis">
            <article>
              <span>Conductores visibles</span>
              <strong>{visibleSummary.drivers}</strong>
              <small>Filtrados uno por uno desde el buscador</small>
            </article>
            <article>
              <span>Viajes visibles</span>
              <strong>{visibleSummary.trips}</strong>
              <small>Total acumulado del grupo mostrado</small>
            </article>
            <article>
              <span>Completados</span>
              <strong>{visibleSummary.completed}</strong>
              <small>Periodo {periodLabelMap[performanceRange].toLowerCase()}</small>
            </article>
            <article>
              <span>Ingresos visibles</span>
              <strong>{formatCurrency(visibleSummary.revenue)}</strong>
              <small>Listo para exportar o imprimir</small>
            </article>
          </div>
        </div>

        <div className="driver-report-table-shell">
          <div className="driver-report-table-wrap">
            <table className="driver-report-table">
              <thead>
                <tr>
                  <th>Conductor</th>
                  <th>Estado</th>
                  <th>Viajes</th>
                  <th>Completados</th>
                  <th>Cancelados</th>
                  <th>Ingresos</th>
                  <th>Ultimo viaje</th>
                  <th>Accion</th>
                </tr>
              </thead>
              <tbody>
                {filteredRows.length === 0 && (
                  <tr>
                    <td colSpan={8}>
                      <div className="driver-report-empty">No hay conductores que coincidan con ese filtro.</div>
                    </td>
                  </tr>
                )}
                {filteredRows.map((row) => (
                  <tr key={row.driverId}>
                    <td>
                      <div className="driver-report-driver-cell">
                        <span className="driver-report-bar-avatar">{getInitials(row.fullName || row.phone)}</span>
                        <div>
                          <strong>{row.fullName || row.phone}</strong>
                          <small>{row.phone}</small>
                        </div>
                      </div>
                    </td>
                    <td>
                      <span className={row.isAvailable ? 'status-pill success' : 'status-pill danger'}>
                        {row.isAvailable ? 'Disponible' : 'No disponible'}
                      </span>
                    </td>
                    <td>{row.totalTrips}</td>
                    <td>{row.completedTrips}</td>
                    <td>{row.cancelledTrips}</td>
                    <td>{formatCurrency(row.revenue)}</td>
                    <td>{formatDateTime(row.lastTripAt, 'Sin viaje visible')}</td>
                    <td>
                      <Button variant="secondary" onClick={() => void onLoadTrips(row.driverId)}>
                        Ver detalle
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="driver-report-mobile-list">
            {filteredRows.length === 0 && <div className="driver-report-empty">No hay resultados visibles.</div>}
            {filteredRows.map((row) => (
              <article key={row.driverId} className="driver-report-mobile-card">
                <div className="driver-report-driver-cell">
                  <span className="driver-report-bar-avatar">{getInitials(row.fullName || row.phone)}</span>
                  <div>
                    <strong>{row.fullName || row.phone}</strong>
                    <small>{row.phone}</small>
                  </div>
                </div>
                <div className="driver-report-mobile-grid">
                  <span>Viajes: {row.totalTrips}</span>
                  <span>Completados: {row.completedTrips}</span>
                  <span>Cancelados: {row.cancelledTrips}</span>
                  <span>Ingresos: {formatCurrency(row.revenue)}</span>
                </div>
                <Button variant="secondary" onClick={() => void onLoadTrips(row.driverId)}>
                  Ver detalle
                </Button>
              </article>
            ))}
          </div>
        </div>

        {selectedDriverTrips && (
          <div className="driver-report-detail-card">
            <div className="driver-report-detail-head">
              <div>
                <strong>{selectedDriverTrips.driver.fullName || selectedDriverTrips.driver.phone}</strong>
                <span>Detalle individual del conductor seleccionado</span>
              </div>
              <div className="driver-report-detail-actions">
                <span className={selectedDriverTrips.driver.isAvailable ? 'status-pill success' : 'status-pill danger'}>
                  {selectedDriverTrips.driver.isAvailable ? 'En linea' : 'Fuera de linea'}
                </span>
                <Button variant="secondary" onClick={onCloseTrips}>
                  Cerrar detalle
                </Button>
              </div>
            </div>

            {selectedSummary && (
              <div className="driver-report-detail-kpis">
                <article>
                  <span>Viajes</span>
                  <strong>{selectedSummary.total}</strong>
                </article>
                <article>
                  <span>Completados</span>
                  <strong>{selectedSummary.completed}</strong>
                </article>
                <article>
                  <span>Cancelados</span>
                  <strong>{selectedSummary.cancelled}</strong>
                </article>
                <article>
                  <span>Ingresos</span>
                  <strong>{formatCurrency(selectedSummary.revenue)}</strong>
                </article>
              </div>
            )}

            <div className="driver-report-trip-list">
              {selectedDriverTrips.trips.length === 0 && <div className="driver-report-empty">No hay viajes cargados para este conductor.</div>}
              {selectedDriverTrips.trips.slice(0, 12).map((trip) => (
                <article key={trip.id} className="driver-report-trip-row">
                  <div>
                    <strong>Viaje {trip.id.slice(0, 8)}</strong>
                    <span>{trip.passengerName || trip.passengerPhone || 'Pasajero sin dato visible'}</span>
                  </div>
                  <div>
                    <strong>{trip.status}</strong>
                    <span>{formatDateTime(trip.completedAt || trip.acceptedAt || trip.requestedAt, 'Sin fecha')}</span>
                  </div>
                  <div>
                    <strong>{formatCurrency(Number(trip.fareAmount || 0))}</strong>
                    <span>{trip.promotionalTrip ? 'Promocional' : 'Tarifa normal'}</span>
                  </div>
                </article>
              ))}
            </div>
          </div>
        )}
      </div>
    </Card>
  )
}
