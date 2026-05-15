import type { AdminView, ManagedUserForm } from '../types/admin'

const envApiBase = import.meta.env.VITE_API_BASE_URL?.trim()
const envWsBase = import.meta.env.VITE_WS_URL?.trim()

export const API_BASE = envApiBase && envApiBase.length > 0 ? envApiBase : '/api'
export const WS_BASE =
  envWsBase && envWsBase.length > 0
    ? envWsBase
    : typeof window !== 'undefined'
      ? window.location.origin
      : 'http://localhost:5173'
export const CITY_CENTER: [number, number] = [-19.5836, -65.7531]

export const APP_ROUTES = {
  login: '/login',
  dashboard: '/dashboard',
  dashboardMap: '/dashboard/mapa',
  dashboardDrivers: '/dashboard/conductores',
  dashboardVehicles: '/dashboard/vehiculos',
  dashboardTrips: '/dashboard/viajes',
  dashboardUsers: '/dashboard/usuarios',
  dashboardReports: '/dashboard/reportes',
  dashboardSettings: '/dashboard/configuracion',
  overview: '/inicio',
  map: '/mapa',
  users: '/usuarios',
  activity: '/actividad',
  stats: '/estadisticas',
  support: '/soporte',
  devices: '/dispositivos',
  profile: '/perfil',
} as const

export const DASHBOARD_NAV_ITEMS = [
  {
    key: 'dashboard',
    label: 'Dashboard',
    hint: 'Resumen ejecutivo',
    to: APP_ROUTES.dashboard,
    icon: 'dashboard',
    description: 'Metricas, ingresos y estado global de la plataforma.',
  },
  {
    key: 'mapa',
    label: 'Mapa en vivo',
    hint: 'Seguimiento operativo',
    to: APP_ROUTES.dashboardMap,
    icon: 'map',
    description: 'Monitoreo visual de autos, cobertura y actividad en tiempo real.',
  },
  {
    key: 'conductores',
    label: 'Conductores',
    hint: 'Flota humana',
    to: APP_ROUTES.dashboardDrivers,
    icon: 'drivers',
    description: 'Disponibilidad, aprobaciones y desempeno de los conductores.',
  },
  {
    key: 'vehiculos',
    label: 'Vehiculos',
    hint: 'Unidades y equipos',
    to: APP_ROUTES.dashboardVehicles,
    icon: 'vehicles',
    description: 'Estado operativo de unidades, reemplazos y accesos.',
  },
  {
    key: 'viajes',
    label: 'Viajes',
    hint: 'Operacion activa',
    to: APP_ROUTES.dashboardTrips,
    icon: 'trips',
    description: 'Seguimiento de viajes activos y contexto de servicio.',
  },
  {
    key: 'usuarios',
    label: 'Usuarios',
    hint: 'CRUD centralizado',
    to: APP_ROUTES.dashboardUsers,
    icon: 'users',
    description: 'Gestion de cuentas, historial y telefonos desde central.',
  },
  {
    key: 'reportes',
    label: 'Reportes',
    hint: 'Analitica operativa',
    to: APP_ROUTES.dashboardReports,
    icon: 'reports',
    description: 'Estadisticas, soporte y actividad consolidada.',
  },
  {
    key: 'configuracion',
    label: 'Configuracion',
    hint: 'Sistema y central',
    to: APP_ROUTES.dashboardSettings,
    icon: 'settings',
    description: 'Perfil institucional, modo offline y parametros clave.',
  },
] as const

export const PAGE_META = {
  [APP_ROUTES.dashboard]: { title: 'Dashboard', subtitle: 'Vista ejecutiva de movilidad y rendimiento en tiempo real.' },
  [APP_ROUTES.dashboardMap]: { title: 'Mapa en vivo', subtitle: 'Mapa protagonista con unidades, estados y cobertura activa.' },
  [APP_ROUTES.dashboardDrivers]: { title: 'Conductores', subtitle: 'Disponibilidad, acceso y desempeno de la flota humana.' },
  [APP_ROUTES.dashboardVehicles]: { title: 'Vehiculos', subtitle: 'Control de equipos, unidades digitales y estado operativo.' },
  [APP_ROUTES.dashboardTrips]: { title: 'Viajes', subtitle: 'Monitoreo de viajes en curso y actividad de servicio.' },
  [APP_ROUTES.dashboardUsers]: { title: 'Usuarios', subtitle: 'CRUD profesional de pasajeros y conductores.' },
  [APP_ROUTES.dashboardReports]: { title: 'Reportes', subtitle: 'Indicadores, soporte y actividad para toma de decisiones.' },
  [APP_ROUTES.dashboardSettings]: { title: 'Configuracion', subtitle: 'Central institucional, promociones y mapa offline.' },
} as const

export const VIEW_LABELS: Record<AdminView, string> = {
  overview: 'Inicio',
  map: 'Mapa',
  users: 'Usuarios',
  activity: 'Actividad',
  stats: 'Estadisticas',
  support: 'Soporte',
  devices: 'Dispositivos',
  profile: 'Perfil',
}

export const VIEW_DESCRIPTIONS: Record<AdminView, string> = {
  overview: 'Vision ejecutiva de la operacion, aprobaciones y pulso comercial en un solo lugar.',
  map: 'Mapa operativo con lectura rapida de disponibilidad, actividad y cobertura de la flota.',
  users: 'Directorio operativo para revisar cuentas, numeros, historial y estado por persona.',
  activity: 'Linea de tiempo centralizada con viajes, equipos y soporte para reaccion inmediata.',
  stats: 'Lectura por conductor, eficiencia, volumen y top del periodo para decisiones rapidas.',
  support: 'Mesa de atencion con filtros visibles, estados y contexto claro por reporte.',
  devices: 'Gobierno de equipos, autorizaciones y reemplazos con trazabilidad por usuario.',
  profile: 'Informacion institucional de la central, accesos y estado de la operacion.',
}

export const NAV_ITEMS: Array<{ view: AdminView; label: string; hint: string; to: string }> = [
  { view: 'overview', label: 'Inicio', hint: 'Resumen general', to: APP_ROUTES.overview },
  { view: 'map', label: 'Mapa', hint: 'Flota y zonas', to: APP_ROUTES.map },
  { view: 'users', label: 'Usuarios', hint: 'CRUD y directorio', to: APP_ROUTES.users },
  { view: 'activity', label: 'Actividad', hint: 'Eventos recientes', to: APP_ROUTES.activity },
  { view: 'stats', label: 'Estadisticas', hint: 'Rendimiento y reportes', to: APP_ROUTES.stats },
  { view: 'support', label: 'Soporte', hint: 'Casos y filtros', to: APP_ROUTES.support },
  { view: 'devices', label: 'Dispositivos', hint: 'Control de accesos', to: APP_ROUTES.devices },
  { view: 'profile', label: 'Perfil', hint: 'Central y sesion', to: APP_ROUTES.profile },
]

export const DEFAULT_LOGIN = {
  username: 'centralflashgo',
  password: 'FlashGo2026',
  phone: '+59170000001',
  otp: '123456',
}

export const EMPTY_USER_FORM = (): ManagedUserForm => ({
  phone: '',
  role: 'passenger',
  firstName: '',
  lastName: '',
  email: '',
  address: '',
  password: '',
  profileCompleted: false,
  licenseNumber: '',
  accessStatus: 'PENDIENTE',
})
