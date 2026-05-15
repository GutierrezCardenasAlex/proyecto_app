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
  overview: '/inicio',
  map: '/mapa',
  users: '/usuarios',
  activity: '/actividad',
  stats: '/estadisticas',
  support: '/soporte',
  devices: '/dispositivos',
  profile: '/perfil',
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
