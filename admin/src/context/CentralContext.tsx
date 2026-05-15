import { createContext, useEffect, useMemo, useRef, useState, type PropsWithChildren } from 'react'
import { io } from 'socket.io-client'
import type {
  ActivityEvent,
  Dashboard,
  DeviceRow,
  Driver,
  DriverPerformanceResponse,
  DriverTripsResponse,
  ManagedUserForm,
  ManagedUserRow,
  NotificationKind,
  OfflineMapStatus,
  PendingDriverAccessRow,
  PerformanceRange,
  PromoSettings,
  SupportReport,
  Trip,
  UserSummary,
} from '../types/admin'
import { adminService } from '../services/adminService'
import { userService } from '../services/userService'
import { useAuth } from '../hooks/useAuth'
import { EMPTY_USER_FORM, WS_BASE } from '../utils/constants'
import { formatClockNow } from '../utils/helpers'

type CentralContextValue = {
  dashboard: Dashboard
  drivers: Driver[]
  trips: Trip[]
  pendingDrivers: PendingDriverAccessRow[]
  pendingDevices: DeviceRow[]
  allDevices: DeviceRow[]
  managedUsers: ManagedUserRow[]
  promoSettings: PromoSettings
  offlineMapStatus: OfflineMapStatus
  supportReports: SupportReport[]
  performanceRange: PerformanceRange
  driverPerformance: DriverPerformanceResponse
  selectedDriverTrips: DriverTripsResponse | null
  selectedHistoryUser: UserSummary | null
  selectedManagedUser: ManagedUserRow | null
  userHistory: DeviceRow[]
  managedUserForm: ManagedUserForm
  userFormMode: 'create' | 'edit'
  phoneDraft: string
  driverAccessNote: string
  lastUpdatedAt: string | null
  mapFullscreen: boolean
  adminSearch: string
  loading: boolean
  error: string | null
  notificationAudience: 'all' | 'passengers' | 'drivers' | 'user'
  notificationPhone: string
  notificationKind: NotificationKind
  notificationTitle: string
  notificationMessage: string
  supportRoleFilter: 'all' | 'passenger' | 'driver'
  supportStatusFilter: 'all' | 'ABIERTO' | 'CERRADO'
  supportSearch: string
  filteredManagedUsers: ManagedUserRow[]
  filteredSupportReports: SupportReport[]
  filteredActivityFeed: ActivityEvent[]
  supportSummary: {
    open: number
    closed: number
    passengers: number
    drivers: number
  }
  executiveSignals: Array<{ label: string; value: string; tone: 'success' | 'warning' | 'danger' }>
  refreshAll: () => Promise<void>
  setAdminSearch: (value: string) => void
  setMapFullscreen: (value: boolean) => void
  setDriverAccessNote: (value: string) => void
  setPhoneDraft: (value: string) => void
  setSupportRoleFilter: (value: 'all' | 'passenger' | 'driver') => void
  setSupportStatusFilter: (value: 'all' | 'ABIERTO' | 'CERRADO') => void
  setSupportSearch: (value: string) => void
  setNotificationAudience: (value: 'all' | 'passengers' | 'drivers' | 'user') => void
  setNotificationPhone: (value: string) => void
  setNotificationKind: (value: NotificationKind) => void
  setNotificationTitle: (value: string) => void
  setNotificationMessage: (value: string) => void
  openCreateUserForm: () => void
  openEditUserForm: (user: ManagedUserRow) => void
  updateManagedUserForm: <K extends keyof ManagedUserForm>(field: K, value: ManagedUserForm[K]) => void
  saveManagedUser: () => Promise<void>
  deleteManagedUser: (user: ManagedUserRow) => Promise<void>
  loadUserHistory: (user: UserSummary) => Promise<void>
  changeUserPhone: () => Promise<void>
  replaceDevice: (deviceId: number) => Promise<void>
  updateDeviceStatus: (deviceId: number, status: 'AUTORIZADO' | 'RECHAZADO') => Promise<void>
  updateDriverAccess: (driverId: string, status: 'AUTORIZADO' | 'RECHAZADO', note?: string) => Promise<void>
  updatePromoStatus: (enabled: boolean) => Promise<void>
  sendAdminNotification: () => Promise<void>
  loadDriverPerformance: (range: PerformanceRange) => Promise<void>
  loadDriverTrips: (driverId: string) => Promise<void>
  closeDriverTrips: () => void
  clearError: () => void
}

const emptyDashboard: Dashboard = { drivers: 0, trips: 0, activeTrips: 0, revenue: '0.00', pendingDevices: 0 }
const emptyPromo: PromoSettings = { enabled: true, cycleLength: 5, rewardCredits: 1, updatedAt: null }
const emptyOffline: OfflineMapStatus = {
  enabled: false,
  status: 'PENDIENTE',
  regionName: 'Potosi ciudad',
  sourceHost: null,
  sourceType: 'no-configurado',
  message: 'La descarga offline aun no fue habilitada por central.',
}
const emptyPerformance: DriverPerformanceResponse = {
  range: 'day',
  generatedAt: '',
  summary: { totalTrips: 0, completedTrips: 0, cancelledTrips: 0, promoTrips: 0, revenue: 0, activeDrivers: 0 },
  rows: [],
}

export const CentralContext = createContext<CentralContextValue | null>(null)

export function CentralProvider({ children }: PropsWithChildren) {
  const { token, logout } = useAuth()
  const mountedRef = useRef(true)

  const [dashboard, setDashboard] = useState<Dashboard>(emptyDashboard)
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [trips, setTrips] = useState<Trip[]>([])
  const [pendingDrivers, setPendingDrivers] = useState<PendingDriverAccessRow[]>([])
  const [pendingDevices, setPendingDevices] = useState<DeviceRow[]>([])
  const [allDevices, setAllDevices] = useState<DeviceRow[]>([])
  const [managedUsers, setManagedUsers] = useState<ManagedUserRow[]>([])
  const [promoSettings, setPromoSettings] = useState<PromoSettings>(emptyPromo)
  const [offlineMapStatus, setOfflineMapStatus] = useState<OfflineMapStatus>(emptyOffline)
  const [supportReports, setSupportReports] = useState<SupportReport[]>([])
  const [performanceRange, setPerformanceRange] = useState<PerformanceRange>('day')
  const [driverPerformance, setDriverPerformance] = useState<DriverPerformanceResponse>(emptyPerformance)
  const [selectedDriverTrips, setSelectedDriverTrips] = useState<DriverTripsResponse | null>(null)
  const [selectedHistoryUser, setSelectedHistoryUser] = useState<UserSummary | null>(null)
  const [selectedManagedUser, setSelectedManagedUser] = useState<ManagedUserRow | null>(null)
  const [userHistory, setUserHistory] = useState<DeviceRow[]>([])
  const [managedUserForm, setManagedUserForm] = useState<ManagedUserForm>(EMPTY_USER_FORM())
  const [userFormMode, setUserFormMode] = useState<'create' | 'edit'>('create')
  const [phoneDraft, setPhoneDraft] = useState('')
  const [driverAccessNote, setDriverAccessNote] = useState('')
  const [lastUpdatedAt, setLastUpdatedAt] = useState<string | null>(null)
  const [mapFullscreen, setMapFullscreen] = useState(false)
  const [adminSearch, setAdminSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notificationAudience, setNotificationAudience] = useState<'all' | 'passengers' | 'drivers' | 'user'>('all')
  const [notificationPhone, setNotificationPhone] = useState('')
  const [notificationKind, setNotificationKind] = useState<NotificationKind>('nuevo')
  const [notificationTitle, setNotificationTitle] = useState('')
  const [notificationMessage, setNotificationMessage] = useState('')
  const [supportRoleFilter, setSupportRoleFilter] = useState<'all' | 'passenger' | 'driver'>('all')
  const [supportStatusFilter, setSupportStatusFilter] = useState<'all' | 'ABIERTO' | 'CERRADO'>('all')
  const [supportSearch, setSupportSearch] = useState('')

  const filteredManagedUsers = useMemo(() => {
    const query = adminSearch.trim().toLowerCase()
    if (!query) return managedUsers
    return managedUsers.filter((user) =>
      `${user.full_name ?? ''} ${user.phone} ${user.role ?? ''} ${user.email ?? ''}`.toLowerCase().includes(query),
    )
  }, [adminSearch, managedUsers])

  const activityFeed = useMemo<ActivityEvent[]>(() => {
    const tripEvents = trips.map<ActivityEvent>((trip) => ({
      id: `trip-${trip.id}`,
      title: `Viaje ${trip.id.slice(0, 8)}`,
      detail: trip.driver_id ? 'Asignado a conductor' : 'Pendiente de asignacion',
      meta: trip.status,
      createdAt: new Date().toISOString(),
      tone: trip.driver_id ? 'success' : 'warning',
    }))

    const supportEvents = supportReports.slice(0, 8).map<ActivityEvent>((report) => ({
      id: `support-${report.id}`,
      title: report.full_name || report.phone,
      detail: report.message,
      meta: `Soporte · ${report.category}`,
      createdAt: report.created_at,
      tone: report.status === 'ABIERTO' ? 'warning' : 'success',
    }))

    const deviceEvents = pendingDevices.slice(0, 8).map<ActivityEvent>((device) => ({
      id: `device-${device.id}`,
      title: device.full_name || device.phone,
      detail: `${device.device_name || 'Equipo desconocido'} · ${device.platform || 'sin plataforma'}`,
      meta: `Dispositivo ${device.status}`,
      createdAt: device.updated_at ?? device.created_at,
      tone: device.status === 'PENDIENTE' ? 'warning' : device.status === 'AUTORIZADO' ? 'success' : 'danger',
    }))

    return [...tripEvents, ...supportEvents, ...deviceEvents]
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 18)
  }, [pendingDevices, supportReports, trips])

  const filteredActivityFeed = useMemo(() => {
    const query = adminSearch.trim().toLowerCase()
    if (!query) return activityFeed
    return activityFeed.filter((event) => `${event.title} ${event.detail} ${event.meta}`.toLowerCase().includes(query))
  }, [activityFeed, adminSearch])

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
      return matchesRole && matchesStatus && (query.length === 0 || haystack.includes(query))
    })
  }, [supportReports, supportRoleFilter, supportStatusFilter, supportSearch])

  const executiveSignals = useMemo(
    () => [
      {
        label: 'Flota disponible',
        value: `${drivers.filter((driver) => driver.is_available).length}/${Math.max(drivers.length, 1)}`,
        tone: 'success' as const,
      },
      {
        label: 'Soporte abierto',
        value: `${supportSummary.open}`,
        tone: 'warning' as const,
      },
      {
        label: 'Equipos pendientes',
        value: `${pendingDevices.length + pendingDrivers.length}`,
        tone: pendingDevices.length + pendingDrivers.length > 0 ? ('danger' as const) : ('success' as const),
      },
    ],
    [drivers, pendingDevices.length, pendingDrivers.length, supportSummary.open],
  )

  const ensureMountedSetError = (message: string) => {
    if (mountedRef.current) {
      setError(message)
    }
  }

  const handleAuthError = (failure: unknown) => {
    if (failure instanceof Error && failure.message.includes('sesion')) {
      logout()
    }
  }

  const refreshAll = async () => {
    if (!token) return

    setLoading(true)
    setError(null)
    try {
      const results = await Promise.allSettled([
        adminService.getDashboard(token),
        adminService.getLiveDrivers(token),
        adminService.getActiveTrips(token),
        adminService.getPendingDrivers(token),
        adminService.getPendingDevices(token),
        adminService.getDevices(token),
        adminService.getUsers(token),
        adminService.getPromoSettings(token),
        adminService.getSupportReports(token),
        adminService.getDriverPerformance(token, performanceRange),
        adminService.getOfflineStatus(token),
      ])

      const [
        dashboardResult,
        driversResult,
        tripsResult,
        pendingDriversResult,
        pendingDevicesResult,
        devicesResult,
        usersResult,
        promoResult,
        supportResult,
        performanceResult,
        offlineResult,
      ] = results

      if (dashboardResult.status === 'fulfilled') setDashboard(dashboardResult.value)
      if (driversResult.status === 'fulfilled') setDrivers(driversResult.value)
      if (tripsResult.status === 'fulfilled') setTrips(tripsResult.value)
      if (pendingDriversResult.status === 'fulfilled') setPendingDrivers(pendingDriversResult.value)
      if (pendingDevicesResult.status === 'fulfilled') setPendingDevices(pendingDevicesResult.value)
      if (devicesResult.status === 'fulfilled') setAllDevices(devicesResult.value)
      if (usersResult.status === 'fulfilled') setManagedUsers(usersResult.value)
      if (promoResult.status === 'fulfilled') setPromoSettings(promoResult.value)
      if (supportResult.status === 'fulfilled') setSupportReports(supportResult.value)
      if (performanceResult.status === 'fulfilled') setDriverPerformance(performanceResult.value)
      if (offlineResult.status === 'fulfilled') setOfflineMapStatus(offlineResult.value)

      const failures = results.filter((entry) => entry.status === 'rejected') as PromiseRejectedResult[]
      if (failures.length > 0) {
        handleAuthError(failures[0].reason)
        ensureMountedSetError(failures[0].reason instanceof Error ? failures[0].reason.message : 'Parte de la central no respondio.')
      }

      if (mountedRef.current) {
        setLastUpdatedAt(formatClockNow())
      }
    } catch (refreshError) {
      handleAuthError(refreshError)
      ensureMountedSetError(refreshError instanceof Error ? refreshError.message : 'No se pudo cargar la central.')
    } finally {
      if (mountedRef.current) {
        setLoading(false)
      }
    }
  }

  useEffect(() => {
    mountedRef.current = true
    return () => {
      mountedRef.current = false
    }
  }, [])

  useEffect(() => {
    if (!token) return
    refreshAll().catch(() => undefined)

    const socket = io(WS_BASE, {
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
      refreshAll().catch(() => undefined)
    }, 8000)

    return () => {
      window.clearInterval(intervalId)
      socket.close()
    }
  }, [token, performanceRange])

  const openCreateUserForm = () => {
    setUserFormMode('create')
    setSelectedManagedUser(null)
    setManagedUserForm(EMPTY_USER_FORM())
  }

  const openEditUserForm = (user: ManagedUserRow) => {
    setUserFormMode('edit')
    setSelectedManagedUser(user)
    setManagedUserForm({
      phone: user.phone,
      role: user.role,
      firstName: user.first_name || '',
      lastName: user.last_name || '',
      email: user.email || '',
      address: user.address || '',
      password: '',
      profileCompleted: Boolean(user.profile_completed),
      licenseNumber: user.license_number || '',
      accessStatus: user.driver_access_status || 'PENDIENTE',
    })
  }

  const updateManagedUserForm = <K extends keyof ManagedUserForm>(field: K, value: ManagedUserForm[K]) => {
    setManagedUserForm((current) => ({ ...current, [field]: value }))
  }

  const loadUserHistory = async (user: UserSummary) => {
    if (!token) return
    setLoading(true)
    setError(null)
    try {
      const payload = await adminService.getUserHistory(token, user)
      setSelectedHistoryUser(user)
      setPhoneDraft(user.phone)
      setUserHistory(payload)
    } catch (historyError) {
      handleAuthError(historyError)
      ensureMountedSetError(historyError instanceof Error ? historyError.message : 'No se pudo cargar el historial del usuario.')
    } finally {
      setLoading(false)
    }
  }

  const changeUserPhone = async () => {
    if (!token || !selectedHistoryUser || !phoneDraft.trim()) return
    setLoading(true)
    setError(null)
    try {
      const payload = await adminService.changeUserPhone(token, selectedHistoryUser.user_id, phoneDraft.trim())
      const nextUser = { ...selectedHistoryUser, phone: payload.user.phone }
      setSelectedHistoryUser(nextUser)
      await refreshAll()
      await loadUserHistory(nextUser)
    } catch (changeError) {
      handleAuthError(changeError)
      ensureMountedSetError(changeError instanceof Error ? changeError.message : 'No se pudo cambiar el telefono.')
    } finally {
      setLoading(false)
    }
  }

  const replaceDevice = async (deviceId: number) => {
    if (!token) return
    setLoading(true)
    setError(null)
    try {
      await adminService.replaceDevice(token, deviceId)
      await refreshAll()
      if (selectedHistoryUser) {
        await loadUserHistory(selectedHistoryUser)
      }
    } catch (replaceError) {
      handleAuthError(replaceError)
      ensureMountedSetError(replaceError instanceof Error ? replaceError.message : 'No se pudo reemplazar el equipo.')
    } finally {
      setLoading(false)
    }
  }

  const updateDeviceStatus = async (deviceId: number, status: 'AUTORIZADO' | 'RECHAZADO') => {
    if (!token) return
    setLoading(true)
    setError(null)
    try {
      await adminService.updateDeviceStatus(token, deviceId, status)
      await refreshAll()
    } catch (deviceError) {
      handleAuthError(deviceError)
      ensureMountedSetError(deviceError instanceof Error ? deviceError.message : 'No se pudo actualizar el dispositivo.')
    } finally {
      setLoading(false)
    }
  }

  const updateDriverAccess = async (driverId: string, status: 'AUTORIZADO' | 'RECHAZADO', note?: string) => {
    if (!token) return
    setLoading(true)
    setError(null)
    try {
      await adminService.updateDriverAccess(token, driverId, status, note)
      setDriverAccessNote('')
      await refreshAll()
    } catch (driverError) {
      handleAuthError(driverError)
      ensureMountedSetError(driverError instanceof Error ? driverError.message : 'No se pudo actualizar el acceso del conductor.')
    } finally {
      setLoading(false)
    }
  }

  const updatePromoStatus = async (enabled: boolean) => {
    if (!token) return
    setLoading(true)
    setError(null)
    try {
      const payload = await adminService.updatePromoStatus(token, {
        enabled,
        cycleLength: promoSettings.cycleLength,
        rewardCredits: promoSettings.rewardCredits,
      })
      setPromoSettings(payload.settings)
      await refreshAll()
    } catch (promoError) {
      handleAuthError(promoError)
      ensureMountedSetError(promoError instanceof Error ? promoError.message : 'No se pudo actualizar la promocion.')
    } finally {
      setLoading(false)
    }
  }

  const sendAdminNotification = async () => {
    if (!token) return
    if (notificationTitle.trim().length < 3 || notificationMessage.trim().length < 6) {
      setError('Escribe un titulo y mensaje validos para la notificacion.')
      return
    }

    setLoading(true)
    setError(null)
    try {
      await adminService.sendNotification(token, {
        audience: notificationAudience,
        phone: notificationAudience === 'user' ? notificationPhone : undefined,
        kind: notificationKind,
        title: notificationTitle,
        message: notificationMessage,
      })
      setNotificationTitle('')
      setNotificationMessage('')
      setNotificationPhone('')
    } catch (notificationError) {
      handleAuthError(notificationError)
      ensureMountedSetError(notificationError instanceof Error ? notificationError.message : 'No se pudo enviar la notificacion.')
    } finally {
      setLoading(false)
    }
  }

  const loadDriverPerformance = async (range: PerformanceRange) => {
    if (!token) return
    setLoading(true)
    setError(null)
    try {
      const payload = await adminService.getDriverPerformance(token, range)
      setPerformanceRange(range)
      setDriverPerformance(payload)
    } catch (performanceError) {
      handleAuthError(performanceError)
      ensureMountedSetError(performanceError instanceof Error ? performanceError.message : 'No se pudo cargar el reporte de conductores.')
    } finally {
      setLoading(false)
    }
  }

  const loadDriverTrips = async (driverId: string) => {
    if (!token) return
    setLoading(true)
    setError(null)
    try {
      const payload = await adminService.getDriverTrips(token, driverId, performanceRange)
      setSelectedDriverTrips(payload)
    } catch (tripsError) {
      handleAuthError(tripsError)
      ensureMountedSetError(tripsError instanceof Error ? tripsError.message : 'No se pudo cargar el detalle del conductor.')
    } finally {
      setLoading(false)
    }
  }

  const saveManagedUser = async () => {
    if (!token) return
    if (!managedUserForm.phone.trim() || !managedUserForm.firstName.trim()) {
      setError('Completa telefono y nombre para guardar el usuario.')
      return
    }
    if (managedUserForm.role === 'driver' && !managedUserForm.licenseNumber.trim()) {
      setError('La licencia es obligatoria para un conductor.')
      return
    }
    if (userFormMode === 'create' && managedUserForm.password.trim().length < 8) {
      setError('La contrasena inicial debe tener al menos 8 caracteres.')
      return
    }

    setLoading(true)
    setError(null)
    try {
      if (userFormMode === 'create') {
        await userService.createUser(token, managedUserForm)
      } else if (selectedManagedUser) {
        await userService.updateUser(token, selectedManagedUser.user_id, managedUserForm)
      }
      await refreshAll()
      openCreateUserForm()
    } catch (userError) {
      handleAuthError(userError)
      ensureMountedSetError(userError instanceof Error ? userError.message : 'No se pudo guardar el usuario.')
    } finally {
      setLoading(false)
    }
  }

  const deleteManagedUser = async (user: ManagedUserRow) => {
    if (!token) return
    if (!window.confirm(`Se eliminara la cuenta ${user.full_name || user.phone}. Deseas continuar?`)) {
      return
    }

    setLoading(true)
    setError(null)
    try {
      await userService.deleteUser(token, user.user_id)
      if (selectedManagedUser?.user_id === user.user_id) {
        openCreateUserForm()
      }
      await refreshAll()
    } catch (deleteError) {
      handleAuthError(deleteError)
      ensureMountedSetError(deleteError instanceof Error ? deleteError.message : 'No se pudo eliminar el usuario.')
    } finally {
      setLoading(false)
    }
  }

  const value = useMemo<CentralContextValue>(
    () => ({
      dashboard,
      drivers,
      trips,
      pendingDrivers,
      pendingDevices,
      allDevices,
      managedUsers,
      promoSettings,
      offlineMapStatus,
      supportReports,
      performanceRange,
      driverPerformance,
      selectedDriverTrips,
      selectedHistoryUser,
      selectedManagedUser,
      userHistory,
      managedUserForm,
      userFormMode,
      phoneDraft,
      driverAccessNote,
      lastUpdatedAt,
      mapFullscreen,
      adminSearch,
      loading,
      error,
      notificationAudience,
      notificationPhone,
      notificationKind,
      notificationTitle,
      notificationMessage,
      supportRoleFilter,
      supportStatusFilter,
      supportSearch,
      filteredManagedUsers,
      filteredSupportReports,
      filteredActivityFeed,
      supportSummary,
      executiveSignals,
      refreshAll,
      setAdminSearch,
      setMapFullscreen,
      setDriverAccessNote,
      setPhoneDraft,
      setSupportRoleFilter,
      setSupportStatusFilter,
      setSupportSearch,
      setNotificationAudience,
      setNotificationPhone,
      setNotificationKind,
      setNotificationTitle,
      setNotificationMessage,
      openCreateUserForm,
      openEditUserForm,
      updateManagedUserForm,
      saveManagedUser,
      deleteManagedUser,
      loadUserHistory,
      changeUserPhone,
      replaceDevice,
      updateDeviceStatus,
      updateDriverAccess,
      updatePromoStatus,
      sendAdminNotification,
      loadDriverPerformance,
      loadDriverTrips,
      closeDriverTrips: () => setSelectedDriverTrips(null),
      clearError: () => setError(null),
    }),
    [
      adminSearch,
      allDevices,
      dashboard,
      driverAccessNote,
      driverPerformance,
      drivers,
      error,
      executiveSignals,
      filteredActivityFeed,
      filteredManagedUsers,
      filteredSupportReports,
      lastUpdatedAt,
      loading,
      managedUserForm,
      managedUsers,
      mapFullscreen,
      notificationAudience,
      notificationKind,
      notificationMessage,
      notificationPhone,
      notificationTitle,
      offlineMapStatus,
      pendingDevices,
      pendingDrivers,
      performanceRange,
      phoneDraft,
      promoSettings,
      selectedDriverTrips,
      selectedHistoryUser,
      selectedManagedUser,
      supportReports,
      supportRoleFilter,
      supportSearch,
      supportStatusFilter,
      supportSummary,
      trips,
      userFormMode,
      userHistory,
    ],
  )

  return <CentralContext.Provider value={value}>{children}</CentralContext.Provider>
}
