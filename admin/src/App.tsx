import { useEffect, useMemo, useRef, useState } from 'react'
import L from 'leaflet'
import { io } from 'socket.io-client'
import './App.css'

const cityCenter: [number, number] = [-19.5836, -65.7531]
const apiBase = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000/api'
const wsBase = import.meta.env.VITE_WS_URL ?? 'http://localhost:3008'

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
  pendingDevices: number
}

type DeviceRow = {
  id: number
  user_id: string
  phone: string
  full_name: string
  role: string
  device_identifier: string
  device_name?: string | null
  platform?: string | null
  status: 'PENDIENTE' | 'AUTORIZADO' | 'RECHAZADO'
  created_at: string
  approved_at?: string | null
  approved_by_name?: string | null
}

type AdminProfile = {
  id: string
  phone: string
  fullName?: string
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
    pendingDevices: 0,
  })
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [trips, setTrips] = useState<Trip[]>([])
  const [pendingDevices, setPendingDevices] = useState<DeviceRow[]>([])
  const [allDevices, setAllDevices] = useState<DeviceRow[]>([])
  const [phone, setPhone] = useState('+59170000001')
  const [otp, setOtp] = useState('123456')
  const [otpRequested, setOtpRequested] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [token, setToken] = useState(localStorage.getItem('admin_token') ?? '')
  const [adminProfile, setAdminProfile] = useState<AdminProfile | null>(() => {
    const raw = localStorage.getItem('admin_profile')
    return raw ? (JSON.parse(raw) as AdminProfile) : null
  })

  const isAuthenticated = token.length > 0

  const authHeaders = useMemo(
    () => ({
      Authorization: `Bearer ${token}`,
    }),
    [token],
  )

  async function loadCentralData() {
    if (!token) {
      return
    }

    const [dashboardResponse, driversResponse, tripsResponse, pendingResponse, devicesResponse] =
      await Promise.all([
        fetch(`${apiBase}/admin/dashboard`, { headers: authHeaders }).then((res) => res.json()),
        fetch(`${apiBase}/admin/drivers/live`, { headers: authHeaders }).then((res) => res.json()),
        fetch(`${apiBase}/admin/active-trips`, { headers: authHeaders }).then((res) => res.json()),
        fetch(`${apiBase}/admin/devices/pending`, { headers: authHeaders }).then((res) => res.json()),
        fetch(`${apiBase}/admin/devices`, { headers: authHeaders }).then((res) => res.json()),
      ])

    setDashboard(dashboardResponse)
    setDrivers(driversResponse)
    setTrips(tripsResponse)
    setPendingDevices(pendingResponse)
    setAllDevices(devicesResponse)
  }

  async function requestOtp() {
    setLoading(true)
    setError(null)
    try {
      const response = await fetch(`${apiBase}/auth/admin/otp/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone }),
      })

      const payload = await response.json()
      if (!response.ok) {
        throw new Error(payload.message ?? 'No se pudo solicitar OTP')
      }

      setOtpRequested(true)
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'No se pudo solicitar OTP')
    } finally {
      setLoading(false)
    }
  }

  async function verifyOtp() {
    setLoading(true)
    setError(null)
    try {
      const response = await fetch(`${apiBase}/auth/admin/otp/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, otp }),
      })

      const payload = await response.json()
      if (!response.ok) {
        throw new Error(payload.message ?? 'No se pudo validar OTP')
      }

      localStorage.setItem('admin_token', payload.token)
      localStorage.setItem('admin_profile', JSON.stringify(payload.admin))
      setToken(payload.token)
      setAdminProfile(payload.admin)
      setOtpRequested(false)
    } catch (verifyError) {
      setError(verifyError instanceof Error ? verifyError.message : 'No se pudo validar OTP')
    } finally {
      setLoading(false)
    }
  }

  function logout() {
    localStorage.removeItem('admin_token')
    localStorage.removeItem('admin_profile')
    setToken('')
    setAdminProfile(null)
    setOtpRequested(false)
    setPendingDevices([])
    setAllDevices([])
  }

  async function updateDeviceStatus(deviceId: number, status: 'AUTORIZADO' | 'RECHAZADO') {
    if (!token) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      const response = await fetch(`${apiBase}/admin/devices/${deviceId}/status`, {
        method: 'POST',
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status }),
      })

      const payload = await response.json()
      if (!response.ok) {
        throw new Error(payload.message ?? 'No se pudo actualizar el dispositivo')
      }

      await loadCentralData()
    } catch (updateError) {
      setError(updateError instanceof Error ? updateError.message : 'No se pudo actualizar el dispositivo')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (!isAuthenticated) {
      return
    }

    loadCentralData().catch(() => {
      setError('No se pudo cargar la central.')
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
  }, [authHeaders, isAuthenticated, token])

  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current || !isAuthenticated) {
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
  }, [isAuthenticated])

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

  if (!isAuthenticated) {
    return (
      <main className="layout auth-layout">
        <section className="hero-panel auth-card">
          <div>
            <p className="eyebrow">Central Taxi Ya</p>
            <h1>Autoriza dispositivos y controla accesos desde oficina.</h1>
            <p className="subtitle">
              Solo la central puede liberar un nuevo telefono para pasajero o conductor.
            </p>
          </div>
          <div className="auth-form">
            <label>
              <span>Numero de la central</span>
              <input value={phone} onChange={(event) => setPhone(event.target.value)} />
            </label>

            {otpRequested && (
              <label>
                <span>OTP</span>
                <input value={otp} onChange={(event) => setOtp(event.target.value)} />
              </label>
            )}

            <button className="primary-button" disabled={loading} onClick={otpRequested ? verifyOtp : requestOtp}>
              {loading ? 'Procesando...' : otpRequested ? 'Ingresar a central' : 'Solicitar OTP'}
            </button>

            {otpRequested && (
              <button className="secondary-button" disabled={loading} onClick={requestOtp}>
                Reenviar OTP
              </button>
            )}

            {error && <div className="error-box">{error}</div>}
          </div>
        </section>
      </main>
    )
  }

  return (
    <main className="layout">
      <section className="hero-panel">
        <div>
          <p className="eyebrow">Central Taxi Ya / Potosi</p>
          <h1>Despacho, control de dispositivos y monitoreo operativo en tiempo real.</h1>
          <p className="subtitle">
            La central valida nuevos equipos, sigue la flota y mantiene el servicio bajo control.
          </p>
        </div>
        <div className="stats">
          <article>
            <span>Conductores</span>
            <strong>{dashboard.drivers}</strong>
          </article>
          <article>
            <span>Viajes</span>
            <strong>{dashboard.trips}</strong>
          </article>
          <article>
            <span>Activos</span>
            <strong>{dashboard.activeTrips}</strong>
          </article>
          <article>
            <span>Pendientes</span>
            <strong>{dashboard.pendingDevices}</strong>
          </article>
        </div>
      </section>

      <section className="toolbar">
        <div>
          <strong>{adminProfile?.fullName ?? 'Central'}</strong>
          <span>{adminProfile?.phone}</span>
        </div>
        <button className="secondary-button" onClick={logout}>
          Cerrar sesion
        </button>
      </section>

      {error && <div className="error-box">{error}</div>}

      <section className="content-grid">
        <div className="map-card">
          <div className="panel-header">
            <h2>Mapa en vivo</h2>
            <span>Potosi protegido por radio operativo</span>
          </div>
          <div ref={mapRef} className="map" />
        </div>

        <div className="side-column">
          <div className="panel">
            <div className="panel-header">
              <h2>Solicitudes de dispositivos</h2>
              <span>{pendingDevices.length} pendientes</span>
            </div>
            <div className="list">
              {pendingDevices.length === 0 && <article className="list-card">Sin solicitudes pendientes.</article>}
              {pendingDevices.map((device) => (
                <article key={device.id} className="list-card stack-card">
                  <div>
                    <strong>{device.full_name || device.phone}</strong>
                    <p>{device.role} · {device.phone}</p>
                    <p>{device.device_name || 'Equipo desconocido'}</p>
                    <p>{device.platform || 'sin plataforma'} · {device.device_identifier}</p>
                  </div>
                  <div className="action-row">
                    <button className="primary-button" onClick={() => updateDeviceStatus(device.id, 'AUTORIZADO')}>
                      Aprobar
                    </button>
                    <button className="danger-button" onClick={() => updateDeviceStatus(device.id, 'RECHAZADO')}>
                      Rechazar
                    </button>
                  </div>
                </article>
              ))}
            </div>
          </div>

          <div className="panel">
            <div className="panel-header">
              <h2>Viajes activos</h2>
              <span>{trips.length} visibles</span>
            </div>
            <div className="list">
              {trips.map((trip) => (
                <article key={trip.id} className="list-card">
                  <div>
                    <strong>{trip.id.slice(0, 8)}</strong>
                    <p>{trip.status}</p>
                  </div>
                  <span>{trip.driver_id ? 'Asignado' : 'Buscando'}</span>
                </article>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="panel devices-panel">
        <div className="panel-header">
          <h2>Dispositivos registrados</h2>
          <span>{allDevices.length} en total</span>
        </div>
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
              {allDevices.map((device) => (
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
                  <td>{device.status}</td>
                  <td>{device.approved_by_name || 'Sin accion'}</td>
                  <td>
                    <div className="action-row compact">
                      <button className="secondary-button" onClick={() => updateDeviceStatus(device.id, 'AUTORIZADO')}>
                        Autorizar
                      </button>
                      <button className="danger-button" onClick={() => updateDeviceStatus(device.id, 'RECHAZADO')}>
                        Bloquear
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  )
}

export default App
