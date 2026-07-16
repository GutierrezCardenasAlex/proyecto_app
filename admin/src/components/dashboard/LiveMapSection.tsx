import { useEffect, useRef } from 'react'
import L from 'leaflet'
import Button from '../common/Button'
import type { Driver, OfflineMapStatus, Trip } from '../../types/admin'
import { CITY_CENTER } from '../../utils/constants'
import { getDriverAvailabilityLabel, getDriverDisplayName, getDriverStatusLabel, getDriverTelemetryLabel, getInitials } from '../../utils/helpers'

type Props = {
  drivers: Driver[]
  trips: Trip[]
  offlineStatus: OfflineMapStatus
  mapFullscreen: boolean
  setMapFullscreen: (value: boolean) => void
}

export default function LiveMapSection({ drivers, trips, offlineStatus, mapFullscreen, setMapFullscreen }: Props) {
  const mapRef = useRef<HTMLDivElement | null>(null)
  const mapCardRef = useRef<HTMLDivElement | null>(null)
  const mapInstanceRef = useRef<ReturnType<typeof L.map> | null>(null)
  const markersLayerRef = useRef<ReturnType<typeof L.layerGroup> | null>(null)
  const didFitInitialDriversRef = useRef(false)

  function escapeHtml(value: string) {
    return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;')
  }

  function visibleDriverPoints() {
    return drivers
      .filter((driver) => driver.location?.lat && driver.location?.lng)
      .map((driver) => [Number(driver.location!.lat), Number(driver.location!.lng)] as [number, number])
      .filter(([lat, lng]) => Number.isFinite(lat) && Number.isFinite(lng))
  }

  function fitVisibleDrivers() {
    const map = mapInstanceRef.current
    const points = visibleDriverPoints()
    if (!map || points.length === 0) return
    if (points.length === 1) {
      map.setView(points[0], 15)
      return
    }
    map.fitBounds(L.latLngBounds(points), { padding: [42, 42], maxZoom: 15 })
  }

  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) return

    const map = L.map(mapRef.current).setView(CITY_CENTER, 13)
    mapInstanceRef.current = map
    markersLayerRef.current = L.layerGroup().addTo(map)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map)

    L.circle(CITY_CENTER, {
      radius: 15000,
      color: '#ec6a36',
      fillOpacity: 0.08,
    }).addTo(map)

    return () => {
      map.remove()
      mapInstanceRef.current = null
      markersLayerRef.current = null
    }
  }, [])

  useEffect(() => {
    if (!markersLayerRef.current) return

    markersLayerRef.current.clearLayers()
    drivers
      .filter((driver) => driver.location?.lat && driver.location?.lng)
      .forEach((driver) => {
        const operationalStatus = getDriverStatusLabel(driver)
        const markerTone = operationalStatus === 'En viaje' ? '#ef4444' : operationalStatus === 'Disponible' ? '#22c55e' : '#f97316'
        const displayName = getDriverDisplayName(driver)
        const lat = Number(driver.location?.lat)
        const lng = Number(driver.location?.lng)
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) return
        const driverIcon = new L.DivIcon({
          className: 'driver-pin',
          html: `<span>${escapeHtml(getInitials(displayName))}</span>`,
          iconSize: [34, 34],
        })
        L.marker([lat, lng], { icon: driverIcon })
          .bindPopup(
            `<div style="min-width:180px">
              <strong>${escapeHtml(displayName)}</strong><br/>
              <span>${escapeHtml(driver.phone || driver.id)}</span><br/>
              <span style="color:${markerTone};font-weight:700">${operationalStatus}</span><br/>
              <span>${escapeHtml(getDriverAvailabilityLabel(driver))}</span><br/>
              <span>${escapeHtml(driver.current_trip_id ? 'En viaje activo' : getDriverTelemetryLabel(driver, 'Ultimo GPS'))}</span>
            </div>`,
          )
          .addTo(markersLayerRef.current!)
      })

    if (!didFitInitialDriversRef.current && visibleDriverPoints().length > 0) {
      didFitInitialDriversRef.current = true
      window.setTimeout(fitVisibleDrivers, 120)
    }
  }, [drivers])

  async function toggleMapFullscreen() {
    const element = mapCardRef.current
    if (!element) return

    if (document.fullscreenElement === element) {
      await document.exitFullscreen()
      setMapFullscreen(false)
    } else {
      await element.requestFullscreen()
      setMapFullscreen(true)
      window.setTimeout(() => mapInstanceRef.current?.invalidateSize(), 120)
    }
  }

  return (
    <section className="map-section">
      <div ref={mapCardRef} className={mapFullscreen ? 'map-card map-card-wide map-card-fullscreen' : 'map-card map-card-wide'}>
        <div className="panel-header">
          <div>
            <h2>Mapa en vivo</h2>
            <span>Potosi protegido por radio operativo · {trips.length} viajes visibles</span>
          </div>
          <div className="map-actions">
            <span className="status-pill success subtle">Disponible</span>
            <span className="status-pill danger subtle">En viaje</span>
            <span className="status-pill warning subtle">Sin disponibilidad</span>
            <div className={offlineStatus.enabled ? 'offline-status-card online' : 'offline-status-card pending'}>
              <span className={offlineStatus.enabled ? 'status-pill success' : 'status-pill warning'}>
                {offlineStatus.status === 'HABILITADO' ? 'Offline habilitado' : 'Offline pendiente'}
              </span>
              <strong>{offlineStatus.regionName}</strong>
              <p>{offlineStatus.message}</p>
              <small>{offlineStatus.sourceHost ? `Fuente: ${offlineStatus.sourceHost}` : 'Sin servidor de tiles configurado.'}</small>
            </div>
            <Button variant="secondary" onClick={toggleMapFullscreen}>
              {mapFullscreen ? 'Salir de pantalla completa' : 'Expandir mapa'}
            </Button>
            <Button variant="secondary" onClick={fitVisibleDrivers} disabled={visibleDriverPoints().length === 0}>
              Ajustar flota
            </Button>
          </div>
        </div>
        <div ref={mapRef} className="map" />
      </div>
    </section>
  )
}
