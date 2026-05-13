import { useEffect, useMemo, useRef, useState } from 'react'
import L from 'leaflet'
import { io } from 'socket.io-client'
import './App.css'

const cityCenter: [number, number] = [-19.5836, -65.7531]
const apiBase = import.meta.env.VITE_API_BASE_URL ?? `${window.location.origin}/api`
const wsBase = import.meta.env.VITE_WS_URL ?? window.location.origin

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

type PromoSettings = {
  enabled: boolean
  cycleLength: number
  rewardCredits: number
  updatedAt?: string | null
}

type OfflineMapStatus = {
  enabled: boolean
  status: 'HABILITADO' | 'PENDIENTE'
  regionName: string
  sourceHost?: string | null
  sourceType: string
  message: string
}

type SupportReport = {
  id: number
  user_id: string
  role: string
  phone: string
  full_name?: string | null
  category: string
  message: string
  status: string
  created_at: string
}

type NotificationKind = 'nuevo' | 'importante' | 'sistema'
type AdminView = 'overview' | 'stats' | 'support' | 'devices'

type PendingDriverAccessRow = {
  id: string
  user_id: string
  license_number: string
  access_status: 'PENDIENTE' | 'AUTORIZADO' | 'RECHAZADO'
  access_note?: string | null
  created_at: string
  updated_at: string
  phone: string
  full_name?: string | null
  first_name?: string | null
  last_name?: string | null
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
  last_login_at?: string | null
}

type AdminProfile = {
  id: string
  phone: string
  fullName?: string
}

type AdminOtpRequestResponse = {
  message?: string
  smsDelivered?: boolean
  otp?: string
}

type UserSummary = {
  user_id: string
  phone: string
  full_name?: string | null
  role?: string
}

type PerformanceRange = 'day' | 'week' | 'month'

type DriverPerformanceRow = {
  driverId: string
  fullName?: string | null
  phone: string
  driverStatus: string
  isAvailable: boolean
  rating: number
  totalTrips: number
  completedTrips: number
  cancelledTrips: number
  promoTrips: number
  tripsThisWeek: number
  revenue: number
  averageFare: number
  lastTripAt?: string | null
}

type DriverPerformanceResponse = {
  range: PerformanceRange
  generatedAt: string
  summary: {
    totalTrips: number
    completedTrips: number
    cancelledTrips: number
    promoTrips: number
    revenue: number
    activeDrivers: number
  }
  rows: DriverPerformanceRow[]
}

type DriverTripHistoryItem = {
  id: string
  status: string
  requestedAt?: string | null
  acceptedAt?: string | null
  completedAt?: string | null
  cancelledAt?: string | null
  promotionalTrip: boolean
  fareAmount?: number | null
  passengerName?: string | null
  passengerPhone?: string | null
  pickupLat?: number | null
  pickupLng?: number | null
  destinationLat?: number | null
  destinationLng?: number | null
}

type DriverTripsResponse = {
  range: 'all' | PerformanceRange
  driver: {
    id: string
    fullName?: string | null
    phone: string
    status: string
    isAvailable: boolean
  }
  trips: DriverTripHistoryItem[]
}

function App() {
  const mapRef = useRef<HTMLDivElement | null>(null)
  const mapCardRef = useRef<HTMLDivElement | null>(null)
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
  const [pendingDrivers, setPendingDrivers] = useState<PendingDriverAccessRow[]>([])
  const [pendingDevices, setPendingDevices] = useState<DeviceRow[]>([])
  const [allDevices, setAllDevices] = useState<DeviceRow[]>([])
  const [promoSettings, setPromoSettings] = useState<PromoSettings>({
    enabled: true,
    cycleLength: 5,
    rewardCredits: 1,
    updatedAt: null,
  })
  const [offlineMapStatus, setOfflineMapStatus] = useState<OfflineMapStatus>({
    enabled: false,
    status: 'PENDIENTE',
    regionName: 'Potosi ciudad',
    sourceHost: null,
    sourceType: 'no-configurado',
    message: 'La descarga offline aun no fue habilitada por central.',
  })
  const [supportReports, setSupportReports] = useState<SupportReport[]>([])
  const [performanceRange, setPerformanceRange] = useState<PerformanceRange>('day')
  const [driverPerformance, setDriverPerformance] = useState<DriverPerformanceResponse>({
    range: 'day',
    generatedAt: '',
    summary: {
      totalTrips: 0,
      completedTrips: 0,
      cancelledTrips: 0,
      promoTrips: 0,
      revenue: 0,
      activeDrivers: 0,
    },
    rows: [],
  })
  const [notificationAudience, setNotificationAudience] = useState<'all' | 'passengers' | 'drivers' | 'user'>('all')
  const [notificationPhone, setNotificationPhone] = useState('')
  const [notificationKind, setNotificationKind] = useState<NotificationKind>('nuevo')
  const [notificationTitle, setNotificationTitle] = useState('')
  const [notificationMessage, setNotificationMessage] = useState('')
  const [activeView, setActiveView] = useState<AdminView>('overview')
  const [supportRoleFilter, setSupportRoleFilter] = useState<'all' | 'passenger' | 'driver'>('all')
  const [supportStatusFilter, setSupportStatusFilter] = useState<'all' | 'ABIERTO' | 'CERRADO'>('all')
  const [supportSearch, setSupportSearch] = useState('')
  const [phone, setPhone] = useState('+59170000001')
  const [selectedDriverTrips, setSelectedDriverTrips] = useState<DriverTripsResponse | null>(null)
  const [otp, setOtp] = useState('123456')
  const [otpRequested, setOtpRequested] = useState(false)
  const [otpFallback, setOtpFallback] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [token, setToken] = useState(localStorage.getItem('admin_token') ?? '')
  const [selectedHistoryUser, setSelectedHistoryUser] = useState<UserSummary | null>(null)
  const [userHistory, setUserHistory] = useState<DeviceRow[]>([])
  const [phoneDraft, setPhoneDraft] = useState('')
  const [driverAccessNote, setDriverAccessNote] = useState('')
  const [adminProfile, setAdminProfile] = useState<AdminProfile | null>(() => {
    const raw = localStorage.getItem('admin_profile')
    return raw ? (JSON.parse(raw) as AdminProfile) : null
  })
  const [lastUpdatedAt, setLastUpdatedAt] = useState<string | null>(null)
  const [mapFullscreen, setMapFullscreen] = useState(false)

  const isAuthenticated = token.length > 0
  const topDriver = driverPerformance.rows[0] ?? null
  const supportSummary = useMemo(
    () => ({
      open: supportReports.filter((report) => report.status === 'ABIERTO').length,
      closed: supportReports.filter((report) => report.status !== 'ABIERTO').length,
      passengers: supportReports.filter((report) => report.role === 'passenger').length,
      drivers: supportReports.filter((report) => report.role === 'driver').length,
    }),
    [supportReports],
  )
  const filteredSupportReports = useMemo(() => {
    const query = supportSearch.trim().toLowerCase()
    return supportReports.filter((report) => {
      const matchesRole = supportRoleFilter === 'all' || report.role === supportRoleFilter
      const matchesStatus = supportStatusFilter === 'all' || report.status === supportStatusFilter
      const haystack = `${report.full_name ?? ''} ${report.phone} ${report.category} ${report.message}`.toLowerCase()
      const matchesSearch = query.length === 0 || haystack.includes(query)
      return matchesRole && matchesStatus && matchesSearch
    })
  }, [supportReports, supportRoleFilter, supportStatusFilter, supportSearch])

  const authHeaders = useMemo(
    () => ({
      Authorization: `Bearer ${token}`,
    }),
    [token],
  )

  async function fetchWithAdminAuth<T>(url: string, init?: RequestInit): Promise<T> {
    const response = await fetch(url, init)
    const payload = await response.json()

    if (response.status === 401) {
      localStorage.removeItem('admin_token')
      localStorage.removeItem('admin_profile')
      setToken('')
      setAdminProfile(null)
      setOtpRequested(false)
      throw new Error('Tu sesion de central vencio o ya no es valida. Vuelve a ingresar.')
    }

    if (!response.ok) {
      throw new Error(payload.message ?? 'No se pudo completar la solicitud.')
    }

    return payload as T
  }

  async function loadCentralData() {
    if (!token) {
      return
    }

    const [dashboardResponse, driversResponse, tripsResponse, pendingDriversResponse, pendingResponse, devicesResponse, promoResponse, supportResponse, performanceResponse, offlineStatusResponse] =
      await Promise.all([
        fetchWithAdminAuth<Dashboard>(`${apiBase}/admin/dashboard`, { headers: authHeaders }),
        fetchWithAdminAuth<Driver[]>(`${apiBase}/admin/drivers/live`, { headers: authHeaders }),
        fetchWithAdminAuth<Trip[]>(`${apiBase}/admin/active-trips`, { headers: authHeaders }),
        fetchWithAdminAuth<PendingDriverAccessRow[]>(`${apiBase}/admin/drivers/pending-access`, { headers: authHeaders }),
        fetchWithAdminAuth<DeviceRow[]>(`${apiBase}/admin/devices/pending`, { headers: authHeaders }),
        fetchWithAdminAuth<DeviceRow[]>(`${apiBase}/admin/devices`, { headers: authHeaders }),
        fetchWithAdminAuth<PromoSettings>(`${apiBase}/admin/promotions/settings`, { headers: authHeaders }),
        fetchWithAdminAuth<SupportReport[]>(`${apiBase}/admin/support/reports/all`, { headers: authHeaders }),
        fetchWithAdminAuth<DriverPerformanceResponse>(`${apiBase}/admin/drivers/performance?range=${performanceRange}`, { headers: authHeaders }),
        fetchWithAdminAuth<OfflineMapStatus>(`${apiBase}/admin/offline/status`, { headers: authHeaders }),
      ])

    setDashboard(dashboardResponse)
    setDrivers(driversResponse)
    setTrips(tripsResponse)
    setPendingDrivers(pendingDriversResponse)
    setPendingDevices(pendingResponse)
    setAllDevices(devicesResponse)
    setPromoSettings(promoResponse)
    setSupportReports(supportResponse)
    setDriverPerformance(performanceResponse)
    setOfflineMapStatus(offlineStatusResponse)
    setLastUpdatedAt(new Date().toLocaleTimeString('es-BO', { hour: '2-digit', minute: '2-digit', second: '2-digit' }))
  }

  async function requestOtp() {
    setLoading(true)
    setError(null)
    try {
      const payload = await fetchWithAdminAuth<AdminOtpRequestResponse>(`${apiBase}/auth/admin/otp/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone }),
      })

      setOtpRequested(true)
      if (!payload.smsDelivered && payload.otp) {
        setOtp(payload.otp)
        setOtpFallback(payload.otp)
        setError(`No se pudo enviar SMS. Usa este OTP de respaldo: ${payload.otp}`)
      } else {
        setOtpFallback(null)
      }
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
      const payload = await fetchWithAdminAuth<{ token: string; admin: AdminProfile }>(`${apiBase}/auth/admin/otp/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, otp }),
      })

      localStorage.setItem('admin_token', payload.token)
      localStorage.setItem('admin_profile', JSON.stringify(payload.admin))
      setToken(payload.token)
      setAdminProfile(payload.admin)
      setOtpRequested(false)
      setOtpFallback(null)
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
    setOtpFallback(null)
    setPendingDrivers([])
    setPendingDevices([])
    setAllDevices([])
  }

  async function updateDriverAccess(driverId: string, status: 'AUTORIZADO' | 'RECHAZADO', note?: string) {
    if (!token) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      await fetchWithAdminAuth(`${apiBase}/admin/drivers/${driverId}/access`, {
        method: 'POST',
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status, note }),
      })

      setDriverAccessNote('')
      await loadCentralData()
    } catch (updateError) {
      setError(updateError instanceof Error ? updateError.message : 'No se pudo actualizar el acceso del conductor')
    } finally {
      setLoading(false)
    }
  }

  async function updateDeviceStatus(deviceId: number, status: 'AUTORIZADO' | 'RECHAZADO') {
    if (!token) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      await fetchWithAdminAuth(`${apiBase}/admin/devices/${deviceId}/status`, {
        method: 'POST',
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status }),
      })

      await loadCentralData()
    } catch (updateError) {
      setError(updateError instanceof Error ? updateError.message : 'No se pudo actualizar el dispositivo')
    } finally {
      setLoading(false)
    }
  }

  async function updatePromoStatus(enabled: boolean) {
    if (!token) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      const payload = await fetchWithAdminAuth<{ message: string; settings: PromoSettings }>(`${apiBase}/admin/promotions/settings`, {
        method: 'POST',
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          enabled,
          cycleLength: promoSettings.cycleLength,
          rewardCredits: promoSettings.rewardCredits,
        }),
      })

      setPromoSettings(payload.settings)
      await loadCentralData()
    } catch (updateError) {
      setError(updateError instanceof Error ? updateError.message : 'No se pudo actualizar la promocion')
    } finally {
      setLoading(false)
    }
  }

  async function sendAdminNotification() {
    if (!token) {
      return
    }
    if (notificationTitle.trim().length < 3 || notificationMessage.trim().length < 6) {
      setError('Escribe un titulo y mensaje validos para la notificacion.')
      return
    }

    setLoading(true)
    setError(null)
    try {
      await fetchWithAdminAuth(`${apiBase}/admin/notifications/send`, {
        method: 'POST',
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          audience: notificationAudience,
          phone: notificationAudience === 'user' ? notificationPhone : undefined,
          kind: notificationKind,
          title: notificationTitle,
          message: notificationMessage,
        }),
      })

      setNotificationTitle('')
      setNotificationMessage('')
      setNotificationPhone('')
    } catch (updateError) {
      setError(updateError instanceof Error ? updateError.message : 'No se pudo enviar la notificacion')
    } finally {
      setLoading(false)
    }
  }

  async function loadDriverPerformance(range: PerformanceRange) {
    if (!token) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      const payload = await fetchWithAdminAuth<DriverPerformanceResponse>(`${apiBase}/admin/drivers/performance?range=${range}`, {
        headers: authHeaders,
      })
      setPerformanceRange(range)
      setDriverPerformance(payload)
    } catch (statsError) {
      setError(statsError instanceof Error ? statsError.message : 'No se pudo cargar el reporte de conductores')
    } finally {
      setLoading(false)
    }
  }

  async function loadDriverTrips(driverId: string) {
    if (!token) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      const payload = await fetchWithAdminAuth<DriverTripsResponse>(
        `${apiBase}/admin/drivers/${driverId}/trips?range=${performanceRange}`,
        { headers: authHeaders },
      )
      setSelectedDriverTrips(payload)
    } catch (driverTripsError) {
      setError(driverTripsError instanceof Error ? driverTripsError.message : 'No se pudo cargar el detalle del conductor')
    } finally {
      setLoading(false)
    }
  }

  async function loadUserHistory(user: UserSummary) {
    if (!token) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      const payload = await fetchWithAdminAuth<DeviceRow[]>(`${apiBase}/admin/devices/user/${user.user_id}/history`, {
        headers: authHeaders,
      })

      setSelectedHistoryUser(user)
      setPhoneDraft(user.phone)
      setUserHistory(payload)
    } catch (historyError) {
      setError(historyError instanceof Error ? historyError.message : 'No se pudo cargar el historial del usuario')
    } finally {
      setLoading(false)
    }
  }

  async function replaceDevice(deviceId: number) {
    if (!token) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      await fetchWithAdminAuth(`${apiBase}/admin/devices/${deviceId}/replace`, {
        method: 'POST',
        headers: authHeaders,
      })

      await loadCentralData()
      if (selectedHistoryUser) {
        await loadUserHistory(selectedHistoryUser)
      }
    } catch (replaceError) {
      setError(replaceError instanceof Error ? replaceError.message : 'No se pudo reemplazar el equipo')
    } finally {
      setLoading(false)
    }
  }

  async function changeUserPhone() {
    if (!token || !selectedHistoryUser || !phoneDraft.trim()) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      const payload = await fetchWithAdminAuth<{ user: { phone: string } }>(`${apiBase}/admin/users/${selectedHistoryUser.user_id}/change-phone`, {
        method: 'POST',
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ phone: phoneDraft.trim() }),
      })

      setSelectedHistoryUser({
        ...selectedHistoryUser,
        phone: payload.user.phone,
      })
      await loadCentralData()
      await loadUserHistory({
        ...selectedHistoryUser,
        phone: payload.user.phone,
      })
    } catch (changeError) {
      setError(changeError instanceof Error ? changeError.message : 'No se pudo cambiar el telefono')
    } finally {
      setLoading(false)
    }
  }

  async function toggleMapFullscreen() {
    const element = mapCardRef.current
    if (!element) {
      return
    }

    try {
      if (document.fullscreenElement === element) {
        await document.exitFullscreen()
      } else {
        await element.requestFullscreen()
      }
    } catch (fullscreenError) {
      setError(fullscreenError instanceof Error ? fullscreenError.message : 'No se pudo cambiar el modo del mapa.')
    }
  }

  useEffect(() => {
    if (!isAuthenticated) {
      return
    }

    loadCentralData().catch(() => {
      setError('No se pudo cargar la central.')
    })

    const socket = io(wsBase, {
      path: '/socket.io',
      transports: ['websocket', 'polling'],
    })
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

    const intervalId = window.setInterval(() => {
      loadCentralData().catch(() => {
        setError('No se pudo actualizar la central automaticamente.')
      })
    }, 8000)

    const handleVisibility = () => {
      if (document.visibilityState === 'visible') {
        loadCentralData().catch(() => {
          setError('No se pudo recargar la central al volver a la pantalla.')
        })
      }
    }

    window.addEventListener('focus', handleVisibility)
    document.addEventListener('visibilitychange', handleVisibility)

    return () => {
      window.clearInterval(intervalId)
      window.removeEventListener('focus', handleVisibility)
      document.removeEventListener('visibilitychange', handleVisibility)
      socket.close()
    }
  }, [authHeaders, isAuthenticated, performanceRange, token])

  useEffect(() => {
    const syncFullscreen = () => {
      setMapFullscreen(document.fullscreenElement === mapCardRef.current)
      window.setTimeout(() => {
        mapInstanceRef.current?.invalidateSize?.()
      }, 120)
    }

    document.addEventListener('fullscreenchange', syncFullscreen)
    return () => {
      document.removeEventListener('fullscreenchange', syncFullscreen)
    }
  }, [])

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
        const markerTone =
          driver.current_trip_id
            ? '#ef4444'
            : driver.is_available
              ? '#22c55e'
              : '#f97316'
        L.marker([Number(driver.location?.lat), Number(driver.location?.lng)], { icon: driverIcon })
          .bindPopup(
            `<div style="min-width:180px">
              <strong>Conductor ${driver.id.slice(0, 8)}</strong><br/>
              <span style="color:${markerTone};font-weight:700">${driver.status}</span><br/>
              <span>${driver.is_available ? 'Disponible' : 'Sin disponibilidad'}</span><br/>
              <span>${driver.current_trip_id ? 'En viaje activo' : 'Esperando solicitud'}</span>
            </div>`,
          )
          .addTo(markersLayerRef.current!)
      })
  }, [drivers])

  if (!isAuthenticated) {
    return (
      <main className="layout auth-layout">
        <section className="hero-panel auth-card">
          <div>
            <p className="eyebrow">Central Flash Go</p>
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

            {otpFallback && <div className="error-box">OTP de respaldo para central: {otpFallback}</div>}

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
          <p className="eyebrow">Central Flash Go / Potosi</p>
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
            <span>Pendientes central</span>
            <strong>{dashboard.pendingDevices + pendingDrivers.length}</strong>
          </article>
        </div>
      </section>

      <section className="toolbar">
        <div>
          <strong>{adminProfile?.fullName ?? 'Central'}</strong>
          <span>
            {adminProfile?.phone}
            {lastUpdatedAt ? ` · Actualizado ${lastUpdatedAt}` : ''}
          </span>
        </div>
        <div className="action-row compact">
          <button
            className={activeView === 'overview' ? 'filter-chip active' : 'filter-chip'}
            onClick={() => setActiveView('overview')}
          >
            Panel
          </button>
          <button
            className={activeView === 'stats' ? 'filter-chip active' : 'filter-chip'}
            onClick={() => setActiveView('stats')}
          >
            Estadisticas
          </button>
          <button
            className={activeView === 'support' ? 'filter-chip active' : 'filter-chip'}
            onClick={() => setActiveView('support')}
          >
            Soporte
          </button>
          <button
            className={activeView === 'devices' ? 'filter-chip active' : 'filter-chip'}
            onClick={() => setActiveView('devices')}
          >
            Dispositivos
          </button>
          <button
            className="secondary-button"
            disabled={loading}
            onClick={() => loadCentralData().catch(() => setError('No se pudo actualizar la central.'))}
          >
            {loading ? 'Actualizando...' : 'Actualizar ahora'}
          </button>
          <button className="secondary-button" onClick={logout}>
            Cerrar sesion
          </button>
        </div>
      </section>

      {error && <div className="error-box">{error}</div>}

      {activeView === 'overview' && (
      <section className="map-section">
        <div ref={mapCardRef} className={mapFullscreen ? 'map-card map-card-wide map-card-fullscreen' : 'map-card map-card-wide'}>
          <div className="panel-header">
            <div>
              <h2>Mapa en vivo</h2>
              <span>Potosi protegido por radio operativo</span>
            </div>
            <div className="map-actions">
              <span className="status-pill success subtle">Disponible</span>
              <span className="status-pill danger subtle">En viaje</span>
              <span className="status-pill warning subtle">Sin disponibilidad</span>
              <div className={offlineMapStatus.enabled ? 'offline-status-card online' : 'offline-status-card pending'}>
                <span className={offlineMapStatus.enabled ? 'status-pill success' : 'status-pill pending'}>
                  {offlineMapStatus.status === 'HABILITADO' ? 'Offline habilitado' : 'Offline pendiente'}
                </span>
                <strong>{offlineMapStatus.regionName}</strong>
                <p>{offlineMapStatus.message}</p>
                <small>{offlineMapStatus.sourceHost ? `Fuente: ${offlineMapStatus.sourceHost}` : 'Sin servidor de tiles configurado.'}</small>
              </div>
              <button className="secondary-button" onClick={toggleMapFullscreen}>
                {mapFullscreen ? 'Salir de pantalla completa' : 'Expandir mapa'}
              </button>
            </div>
          </div>
          <div ref={mapRef} className="map" />
        </div>
      </section>
      )}

      <section className="content-grid">
        <div className="side-column side-column-full">
          {(activeView === 'overview' || activeView === 'stats') && (
          <div className="panel">
            <div className="panel-header">
              <h2>Estadistica de conductores</h2>
              <span>{performanceRange === 'day' ? 'Hoy' : performanceRange === 'week' ? '7 dias' : '30 dias'}</span>
            </div>
            <article className="list-card stack-card promo-card">
              <div className="filter-chip-row">
                <button
                  className={performanceRange === 'day' ? 'filter-chip active' : 'filter-chip'}
                  disabled={loading}
                  onClick={() => loadDriverPerformance('day')}
                >
                  Dia
                </button>
                <button
                  className={performanceRange === 'week' ? 'filter-chip active' : 'filter-chip'}
                  disabled={loading}
                  onClick={() => loadDriverPerformance('week')}
                >
                  Semana
                </button>
                <button
                  className={performanceRange === 'month' ? 'filter-chip active' : 'filter-chip'}
                  disabled={loading}
                  onClick={() => loadDriverPerformance('month')}
                >
                  Mes
                </button>
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
                                <div className="driver-avatar">{(row.fullName || row.phone).trim().charAt(0).toUpperCase()}</div>
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
                              <button className="secondary-button table-action-button" onClick={() => loadDriverTrips(row.driverId)}>
                                Ver historial de viajes
                              </button>
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            </article>
          </div>
          )}

          {activeView === 'overview' && (
          <div className="panel">
            <div className="panel-header">
              <h2>Promociones Flash Go</h2>
              <span>{promoSettings.enabled ? 'Activa' : 'Pausada'}</span>
            </div>
            <article className="list-card stack-card promo-card">
              <div>
                <strong>{promoSettings.enabled ? 'Promo habilitada' : 'Promo detenida'}</strong>
                <p>Cada {promoSettings.cycleLength} viajes pagados desbloquean {promoSettings.rewardCredits} viaje gratis.</p>
                <p>La app del pasajero y del conductor toma este cambio en el siguiente refresh de sesion.</p>
              </div>
              <div className="action-row">
                <button
                  className="primary-button"
                  disabled={loading || promoSettings.enabled}
                  onClick={() => updatePromoStatus(true)}
                >
                  Activar promo
                </button>
                <button
                  className="secondary-button"
                  disabled={loading || !promoSettings.enabled}
                  onClick={() => updatePromoStatus(false)}
                >
                  Pausar promo
                </button>
              </div>
            </article>
          </div>
          )}

          {activeView === 'overview' && (
          <div className="panel">
            <div className="panel-header">
              <h2>Notificaciones central</h2>
              <span>{notificationAudience === 'user' ? 'Usuario puntual' : 'Difusion'}</span>
            </div>
            <article className="list-card stack-card promo-card">
              <div className="phone-change-form">
                <select value={notificationAudience} onChange={(event) => setNotificationAudience(event.target.value as 'all' | 'passengers' | 'drivers' | 'user')}>
                  <option value="all">Todos</option>
                  <option value="passengers">Solo pasajeros</option>
                  <option value="drivers">Solo conductores</option>
                  <option value="user">Usuario por telefono</option>
                </select>
                <select value={notificationKind} onChange={(event) => setNotificationKind(event.target.value as NotificationKind)}>
                  <option value="nuevo">Nuevo</option>
                  <option value="importante">Importante</option>
                  <option value="sistema">Sistema</option>
                </select>
                {notificationAudience === 'user' && (
                  <input
                    value={notificationPhone}
                    onChange={(event) => setNotificationPhone(event.target.value)}
                    placeholder="+591..."
                  />
                )}
                <input
                  value={notificationTitle}
                  onChange={(event) => setNotificationTitle(event.target.value)}
                  placeholder="Titulo de la notificacion"
                />
                <textarea
                  className="note-input"
                  value={notificationMessage}
                  onChange={(event) => setNotificationMessage(event.target.value)}
                  placeholder="Mensaje para la app del pasajero o conductor"
                />
                <button className="primary-button" onClick={sendAdminNotification} disabled={loading}>
                  {loading ? 'Enviando...' : 'Enviar notificacion'}
                </button>
              </div>
            </article>
          </div>
          )}

          {activeView === 'overview' && (
          <div className="panel">
            <div className="panel-header">
              <h2>Conductores por autorizar</h2>
              <span>{pendingDrivers.length} pendientes</span>
            </div>
            <div className="list">
              {pendingDrivers.length === 0 && <article className="list-card">Sin conductores pendientes.</article>}
              {pendingDrivers.map((driver) => (
                <article key={driver.id} className="list-card stack-card">
                  <div>
                    <div className="performance-heading">
                      <strong>{driver.full_name || driver.phone}</strong>
                      <span className={driver.access_status === 'AUTORIZADO' ? 'status-pill success' : driver.access_status === 'RECHAZADO' ? 'status-pill danger' : 'status-pill warning'}>
                        {driver.access_status}
                      </span>
                    </div>
                    <p>conductor · {driver.phone}</p>
                    <p>Licencia: {driver.license_number}</p>
                    {driver.access_note && <p>Nota actual: {driver.access_note}</p>}
                  </div>
                  <div className="stack-actions">
                    <textarea
                      value={driverAccessNote}
                      onChange={(event) => setDriverAccessNote(event.target.value)}
                      placeholder="Nota opcional para central"
                      className="note-input"
                    />
                    <div className="action-row">
                      <button
                        className="success-button"
                        onClick={() => updateDriverAccess(driver.id, 'AUTORIZADO', driverAccessNote)}
                      >
                        Autorizar conductor
                      </button>
                      <button
                        className="danger-button"
                        onClick={() => updateDriverAccess(driver.id, 'RECHAZADO', driverAccessNote)}
                      >
                        Rechazar
                      </button>
                      <button
                        className="secondary-button"
                        onClick={() =>
                          loadUserHistory({
                            user_id: driver.user_id,
                            phone: driver.phone,
                            full_name: driver.full_name,
                            role: 'driver',
                          })
                        }
                      >
                        Ver usuario
                      </button>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </div>
          )}

          {activeView === 'overview' && (
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
                    <button className="success-button" onClick={() => updateDeviceStatus(device.id, 'AUTORIZADO')}>
                      Aprobar
                    </button>
                    <button className="danger-button" onClick={() => updateDeviceStatus(device.id, 'RECHAZADO')}>
                      Rechazar
                    </button>
                    <button
                      className="secondary-button"
                      onClick={() =>
                        loadUserHistory({
                          user_id: device.user_id,
                          phone: device.phone,
                          full_name: device.full_name,
                          role: device.role,
                        })
                      }
                    >
                      Ver historial
                    </button>
                  </div>
                </article>
              ))}
            </div>
          </div>
          )}

          {activeView === 'overview' && (
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
          )}

          {(activeView === 'overview' || activeView === 'support') && (
          <div className="panel">
            <div className="panel-header">
              <h2>Reportes de soporte</h2>
              <span>{filteredSupportReports.length} visibles</span>
            </div>
            <article className="list-card stack-card promo-card support-filters-card">
              <div className="mini-stats-grid support-summary-grid">
                <div className="mini-stat-card">
                  <span>Abiertos</span>
                  <strong>{supportSummary.open}</strong>
                </div>
                <div className="mini-stat-card">
                  <span>Cerrados</span>
                  <strong>{supportSummary.closed}</strong>
                </div>
                <div className="mini-stat-card">
                  <span>Pasajeros</span>
                  <strong>{supportSummary.passengers}</strong>
                </div>
                <div className="mini-stat-card">
                  <span>Conductores</span>
                  <strong>{supportSummary.drivers}</strong>
                </div>
              </div>
              <div className="support-filter-bar">
                <select value={supportRoleFilter} onChange={(event) => setSupportRoleFilter(event.target.value as 'all' | 'passenger' | 'driver')}>
                  <option value="all">Todos los roles</option>
                  <option value="passenger">Solo pasajeros</option>
                  <option value="driver">Solo conductores</option>
                </select>
                <select value={supportStatusFilter} onChange={(event) => setSupportStatusFilter(event.target.value as 'all' | 'ABIERTO' | 'CERRADO')}>
                  <option value="all">Todos los estados</option>
                  <option value="ABIERTO">Abiertos</option>
                  <option value="CERRADO">Cerrados</option>
                </select>
                <input
                  value={supportSearch}
                  onChange={(event) => setSupportSearch(event.target.value)}
                  placeholder="Buscar por nombre, telefono, categoria o mensaje"
                />
              </div>
            </article>
            <div className="list">
              {filteredSupportReports.length === 0 && <article className="list-card">No hay reportes con esos filtros.</article>}
              {filteredSupportReports.map((report) => (
                <article key={report.id} className="support-card">
                  <div className="support-card-top">
                    <div>
                      <strong>{report.full_name || report.phone}</strong>
                      <p>{report.role} · {report.phone}</p>
                    </div>
                    <div className="support-badges">
                      <span className="status-pill warning subtle">{report.category}</span>
                      <span className={report.status === 'ABIERTO' ? 'status-pill warning subtle' : 'status-pill success subtle'}>
                        {report.status}
                      </span>
                    </div>
                  </div>
                  <div className="support-message">
                    {report.message}
                  </div>
                  <div className="support-card-footer">
                    <span>Enviado</span>
                    <strong>{new Date(report.created_at).toLocaleString('es-BO')}</strong>
                  </div>
                </article>
              ))}
            </div>
          </div>
          )}
        </div>
      </section>

      {(activeView === 'overview' || activeView === 'devices') && (
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
                  <td>
                    <span className={device.status === 'AUTORIZADO' ? 'status-pill success' : device.status === 'RECHAZADO' ? 'status-pill danger' : 'status-pill warning'}>
                      {device.status}
                    </span>
                  </td>
                  <td>{device.approved_by_name || 'Sin accion'}</td>
                  <td>
                    <div className="action-row compact">
                      <button
                        className="secondary-button"
                        onClick={() =>
                          loadUserHistory({
                            user_id: device.user_id,
                            phone: device.phone,
                            full_name: device.full_name,
                            role: device.role,
                          })
                        }
                      >
                        Historial
                      </button>
                      <button className="success-button" onClick={() => updateDeviceStatus(device.id, 'AUTORIZADO')}>
                        Autorizar
                      </button>
                      <button className="primary-button" onClick={() => replaceDevice(device.id)}>
                        Reemplazar
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
      )}

      {selectedHistoryUser && (
        <section className="panel devices-panel">
          <div className="panel-header">
            <h2>Historial por usuario</h2>
            <span>
              {selectedHistoryUser.full_name || selectedHistoryUser.phone} · {selectedHistoryUser.phone}
            </span>
          </div>
          <div className="phone-change-card">
            <div>
              <strong>Cambiar telefono autorizado</strong>
              <p>
                La central puede mover esta cuenta a un nuevo numero. El numero viejo queda libre y la cuenta se
                mantiene.
              </p>
            </div>
            <div className="phone-change-form">
              <input
                value={phoneDraft}
                onChange={(event) => setPhoneDraft(event.target.value)}
                placeholder="+591..."
              />
              <button className="primary-button" onClick={changeUserPhone} disabled={loading}>
                Guardar telefono
              </button>
            </div>
          </div>
          <div className="list">
            {userHistory.map((device) => (
              <article key={device.id} className="list-card stack-card">
                <div>
                  <strong>{device.device_name || 'Equipo desconocido'}</strong>
                  <p>{device.platform || 'sin plataforma'} · {device.device_identifier}</p>
                  <p>Estado: {device.status}</p>
                  <p>Ultimo acceso: {device.last_login_at || 'sin registros'}</p>
                  <p>Central: {device.approved_by_name || 'sin accion'}</p>
                </div>
                <div className="action-row">
                  <button className="primary-button" onClick={() => replaceDevice(device.id)}>
                    Autorizar este equipo
                  </button>
                  <button className="secondary-button" onClick={() => updateDeviceStatus(device.id, 'AUTORIZADO')}>
                    Solo autorizar
                  </button>
                  <button className="danger-button" onClick={() => updateDeviceStatus(device.id, 'RECHAZADO')}>
                    Bloquear
                  </button>
                </div>
              </article>
            ))}
          </div>
        </section>
      )}

      {selectedDriverTrips && (
        <section className="panel devices-panel">
          <div className="panel-header">
            <h2>Detalle del conductor</h2>
            <span>
              {selectedDriverTrips.driver.fullName || selectedDriverTrips.driver.phone} · {selectedDriverTrips.trips.length} viajes
            </span>
          </div>
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
                    <strong>{trip.requestedAt ? new Date(trip.requestedAt).toLocaleString('es-BO') : 'Sin dato'}</strong>
                  </div>
                  <div className="performance-metric">
                    <span>Finalizado</span>
                    <strong>
                      {trip.completedAt
                        ? new Date(trip.completedAt).toLocaleString('es-BO')
                        : trip.cancelledAt
                          ? new Date(trip.cancelledAt).toLocaleString('es-BO')
                          : 'En proceso'}
                    </strong>
                  </div>
                </div>
              </article>
            ))}
          </div>
          <div className="action-row">
            <button className="secondary-button" onClick={() => setSelectedDriverTrips(null)}>
              Cerrar detalle
            </button>
          </div>
        </section>
      )}
    </main>
  )
}

export default App
