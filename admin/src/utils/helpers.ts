import type { AdminView } from '../types/admin'
import type { Driver } from '../types/admin'

export function normalizeViewFromPath(pathname: string): AdminView {
  const clean = pathname.replace(/^\//, '').trim().toLowerCase()
  switch (clean) {
    case 'mapa':
      return 'map'
    case 'usuarios':
      return 'users'
    case 'actividad':
      return 'activity'
    case 'estadisticas':
      return 'stats'
    case 'soporte':
      return 'support'
    case 'dispositivos':
      return 'devices'
    case 'perfil':
      return 'profile'
    case 'dashboard':
    case 'inicio':
    default:
      return 'overview'
  }
}

export function formatDateTime(value?: string | null, fallback = 'Sin dato') {
  if (!value) {
    return fallback
  }

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return fallback
  }

  return date.toLocaleString('es-BO')
}

export function formatClockNow() {
  return new Date().toLocaleTimeString('es-BO', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  })
}

export function getInitials(value?: string | null) {
  const clean = (value || '').trim()
  if (!clean) {
    return 'FG'
  }

  return clean
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('')
}

export function getDriverDisplayName(driver: Pick<Driver, 'id' | 'full_name' | 'phone'>) {
  return driver.full_name?.trim() || driver.phone?.trim() || `Conductor ${driver.id.slice(0, 8)}`
}
