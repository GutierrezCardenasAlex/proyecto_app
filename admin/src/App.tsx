import { useEffect, useRef, useState } from 'react'
import L from 'leaflet'
import { io } from 'socket.io-client'
import './App.css'

const cityCenter: [number, number] = [-19.5836, -65.7531]

const driverIcon = new L.DivIcon({
  className: 'driver-pin',
  html: '<span>TX</span>',
  iconSize: [30, 30],
})

type Driver = {
  id: string
  status: string
  is_available: boolean
  current_trip_id?: string | null
  location?: {
    lat?: string
    lng?: string
    updatedAt?: string
  }
}

type Trip = {
  id: string
  status: string
  pickup_lat: number
  pickup_lng: number
  destination_lat: number
  destination_lng: number
  driver_id?: string | null
}

type Dashboard = {
  drivers: number
  trips: number
  activeTrips: number
  revenue: string
}

function App() {
  const mapRef = useRef<HTMLDivElement | null>(null)
  const mapInstanceRef = useRef<any>(null)
  const markersLayerRef = useRef<any>(null)
  const [dashboard, setDashboard] = useState<Dashboard>({
    drivers: 0,
    trips: 0,
    activeTrips: 0,
    revenue: '0.00',
  })
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [trips, setTrips] = useState<Trip[]>([])

  useEffect(() => {
    const apiBase = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000/api'
    const wsBase = import.meta.env.VITE_WS_URL ?? 'http://localhost:3008'

    const load = async () => {
      const [dashboardResponse, driversResponse, tripsResponse] = await Promise.all([
        fetch(`${apiBase}/admin/dashboard`).then((res) => res.json()),
        fetch(`${apiBase}/admin/drivers/live`).then((res) => res.json()),
        fetch(`${apiBase}/admin/active-trips`).then((res) => res.json()),
      ])

      setDashboard(dashboardResponse)
      setDrivers(driversResponse)
      setTrips(tripsResponse)
    }

    load().catch(() => {
      setDashboard({ drivers: 1, trips: 12, activeTrips: 1, revenue: '144.00' })
      setDrivers([
        {
          id: 'demo-driver',
          status: 'available',
          is_available: true,
          location: { lat: '-19.5900', lng: '-65.7540', updatedAt: new Date().toISOString() },
        },
      ])
      setTrips([
        {
          id: 'demo-trip',
          status: 'accepted',
          pickup_lat: -19.5855,
          pickup_lng: -65.7545,
          destination_lat: -19.574,
          destination_lng: -65.745,
          driver_id: 'demo-driver',
        },
      ])
    })

    const socket = io(wsBase, { transports: ['websocket'] })
    socket.emit('join:admin')
    socket.on('driver:location', (payload: { driverId: string; lat: string; lng: string; updatedAt: string }) => {
      setDrivers((current) =>
        current.map((driver) =>
          driver.id === payload.driverId
            ? { ...driver, location: { lat: payload.lat, lng: payload.lng, updatedAt: payload.updatedAt } }
            : driver,
        ),
      )
    })

    return () => {
      socket.close()
    }
  }, [])

  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) {
      return
    }

    const map = L.map(mapRef.current).setView(cityCenter, 13)
    mapInstanceRef.current = map
    markersLayerRef.current = L.layerGroup().addTo(map)

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map)

    L.circle(cityCenter, {
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
    if (!markersLayerRef.current) {
      return
    }

    markersLayerRef.current.clearLayers()
    drivers
      .filter((driver) => driver.location?.lat && driver.location?.lng)
      .forEach((driver) => {
        L.marker([Number(driver.location?.lat), Number(driver.location?.lng)], { icon: driverIcon })
          .bindPopup(`<strong>${driver.id}</strong><br/>${driver.status}`)
          .addTo(markersLayerRef.current!)
      })
  }, [drivers])

  return (
    <main className="layout">
      <section className="hero-panel">
        <div>
          <p className="eyebrow">Taxi Ya / Potosi Control</p>
          <h1>Real-time dispatch operations for a 15 km service boundary.</h1>
          <p className="subtitle">
            Live driver telemetry, active trip monitoring, and dispatch visibility for the Taxi Ya platform.
          </p>
        </div>
        <div className="stats">
          <article>
            <span>Drivers</span>
            <strong>{dashboard.drivers}</strong>
          </article>
          <article>
            <span>Total Trips</span>
            <strong>{dashboard.trips}</strong>
          </article>
          <article>
            <span>Active Trips</span>
            <strong>{dashboard.activeTrips}</strong>
          </article>
          <article>
            <span>Revenue</span>
            <strong>Bs {dashboard.revenue}</strong>
          </article>
        </div>
      </section>

      <section className="content-grid">
        <div className="map-card">
          <div className="panel-header">
            <h2>Live Map</h2>
            <span>Potosi radius lock active</span>
          </div>
          <div ref={mapRef} className="map" />
        </div>

        <div className="side-column">
          <div className="panel">
            <div className="panel-header">
              <h2>Active Trips</h2>
              <span>{trips.length} visible</span>
            </div>
            <div className="list">
              {trips.map((trip) => (
                <article key={trip.id} className="list-card">
                  <div>
                    <strong>{trip.id.slice(0, 8)}</strong>
                    <p>{trip.status}</p>
                  </div>
                  <span>{trip.driver_id ? 'Assigned' : 'Searching'}</span>
                </article>
              ))}
            </div>
          </div>

          <div className="panel">
            <div className="panel-header">
              <h2>Fleet Pulse</h2>
              <span>Redis-backed</span>
            </div>
            <div className="list">
              {drivers.map((driver) => (
                <article key={driver.id} className="list-card">
                  <div>
                    <strong>{driver.id.slice(0, 8)}</strong>
                    <p>{driver.status}</p>
                  </div>
                  <span>{driver.is_available ? 'Available' : 'Busy'}</span>
                </article>
              ))}
            </div>
          </div>
        </div>
      </section>
    </main>
  )
}

export default App
