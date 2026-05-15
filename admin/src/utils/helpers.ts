import type { AdminView } from '../types/admin'
import type { Driver } from '../types/admin'

const DRIVER_SIGNAL_TIMEOUT_MS = 5 * 60 * 1000

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

export function getDriverTelemetryDate(driver: Pick<Driver, 'location'>) {
  const value = driver.location?.updatedAt
  if (!value) return null
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) return null
  return parsed
}

export function hasRecentDriverTelemetry(driver: Pick<Driver, 'location' | 'current_trip_id'>) {
  if (driver.current_trip_id) return true
  const telemetryDate = getDriverTelemetryDate(driver)
  if (!telemetryDate) return false
  return Date.now() - telemetryDate.getTime() <= DRIVER_SIGNAL_TIMEOUT_MS
}

export function getDriverStatusLabel(driver: Pick<Driver, 'current_trip_id' | 'is_available' | 'status' | 'location'>) {
  if (driver.current_trip_id) return 'En viaje'
  if (!hasRecentDriverTelemetry(driver) || driver.status === 'offline' || !driver.is_available) return 'Desconectado'
  return 'Disponible'
}

export function getDriverAvailabilityLabel(driver: Pick<Driver, 'current_trip_id' | 'is_available' | 'status' | 'location'>) {
  return getDriverStatusLabel(driver) === 'Disponible' ? 'Disponible' : 'No disponible'
}

export function getDriverStateValue(driver: Pick<Driver, 'current_trip_id' | 'is_available' | 'status' | 'location'>) {
  if (driver.current_trip_id) return 'in_trip'
  if (!hasRecentDriverTelemetry(driver) || driver.status === 'offline' || !driver.is_available) return 'offline'
  return 'available'
}

export function getDriverTelemetryLabel(driver: Pick<Driver, 'current_trip_id' | 'location'>, recentPrefix = 'GPS') {
  if (driver.current_trip_id) {
    const telemetryDate = getDriverTelemetryDate(driver)
    return telemetryDate ? `${recentPrefix} ${telemetryDate.toLocaleTimeString('es-BO')}` : 'En ruta'
  }

  const telemetryDate = getDriverTelemetryDate(driver)
  if (!telemetryDate) return 'Sin señal reciente'
  if (Date.now() - telemetryDate.getTime() > DRIVER_SIGNAL_TIMEOUT_MS) return 'Sin señal reciente'
  return `${recentPrefix} ${telemetryDate.toLocaleTimeString('es-BO')}`
}

export function getDriverTelemetryDateTimeLabel(driver: Pick<Driver, 'location'>, fallback = 'Sin telemetria') {
  const telemetryDate = getDriverTelemetryDate(driver)
  if (!telemetryDate) return fallback
  return telemetryDate.toLocaleString('es-BO')
}
