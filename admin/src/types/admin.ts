export type NotificationKind = 'nuevo' | 'importante' | 'sistema'

export type AdminView =
  | 'overview'
  | 'map'
  | 'users'
  | 'activity'
  | 'stats'
  | 'support'
  | 'devices'
  | 'profile'

export type Driver = {
  id: string
  user_id?: string
  status: string
  is_available: boolean
  accepts_transport_requests?: boolean
  accepts_delivery_requests?: boolean
  full_name?: string | null
  phone?: string | null
  current_trip_id?: string | null
  location?: {
    lat?: string
    lng?: string
    updatedAt?: string
  }
}

export type DeliveryDriver = {
  id: string
  user_id: string
  status: string
  is_available: boolean
  current_trip_id?: string | null
  accepts_transport_requests: boolean
  accepts_delivery_requests: boolean
  updated_at: string
  full_name?: string | null
  phone?: string | null
  email?: string | null
  vehicle_type?: string | null
  plate?: string | null
  brand?: string | null
  model?: string | null
  color?: string | null
}

export type Trip = {
  id: string
  status: string
  pickup_lat: number
  pickup_lng: number
  destination_lat: number
  destination_lng: number
  driver_id?: string | null
}

export type Dashboard = {
  drivers: number
  trips: number
  activeTrips: number
  revenue: string
  pendingDevices: number
}

export type PromoSettings = {
  enabled: boolean
  cycleLength: number
  rewardCredits: number
  updatedAt?: string | null
}

export type OfflineMapStatus = {
  enabled: boolean
  status: 'HABILITADO' | 'PENDIENTE'
  regionName: string
  sourceHost?: string | null
  sourceType: string
  message: string
}

export type SupportReport = {
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

export type PendingDriverAccessRow = {
  id: string
  user_id: string
  license_number: string
  license_category?: string | null
  license_issue_date?: string | null
  license_expiry_date?: string | null
  access_status: 'PENDIENTE' | 'AUTORIZADO' | 'RECHAZADO'
  access_note?: string | null
  created_at: string
  updated_at: string
  phone: string
  full_name?: string | null
  first_name?: string | null
  last_name?: string | null
  email?: string | null
  address?: string | null
  vehicle_type?: string | null
  plate?: string | null
  brand?: string | null
  model?: string | null
  color?: string | null
  year?: number | null
  verification_ready?: boolean
  missing_fields?: string[]
}

export type DeviceRow = {
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
  updated_at?: string | null
  approved_at?: string | null
  approved_by_name?: string | null
  last_login_at?: string | null
}

export type AdminProfile = {
  id: string
  phone?: string | null
  username?: string | null
  fullName?: string | null
  accessLevel?: 'admin' | 'monitor'
}

export type AdminOtpRequestResponse = {
  message?: string
  smsDelivered?: boolean
  otp?: string
}

export type AdminLoginResponse = {
  message?: string
  admin: AdminProfile
}

export type AuthSessionResponse = {
  token: string
  admin: AdminProfile
}

export type AccessGateResponse = {
  gateToken: string
  access: {
    central: boolean
    monitoring: boolean
  }
}

export type UserSummary = {
  user_id: string
  phone: string
  full_name?: string | null
  role?: string
}

export type PerformanceRange = 'day' | 'week' | 'month'

export type DriverPerformanceRow = {
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

export type DriverPerformanceResponse = {
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

export type DriverTripHistoryItem = {
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

export type DriverTripsResponse = {
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

export type ManagedUserRow = {
  user_id: string
  phone: string
  full_name?: string | null
  first_name?: string | null
  last_name?: string | null
  email?: string | null
  address?: string | null
  role: 'passenger' | 'driver'
  profile_completed: boolean
  created_at: string
  updated_at: string
  driver_id?: string | null
  driver_status?: string | null
  driver_available?: boolean | null
  driver_access_status?: 'PENDIENTE' | 'AUTORIZADO' | 'RECHAZADO' | null
  license_number?: string | null
  vehicle_type?: string | null
  device_count: number
  authorized_devices: number
  pending_devices: number
  support_open_count: number
  total_trips: number
}

export type ManagedUserForm = {
  phone: string
  role: 'passenger' | 'driver'
  firstName: string
  lastName: string
  email: string
  address: string
  password: string
  profileCompleted: boolean
  licenseNumber: string
  accessStatus: 'PENDIENTE' | 'AUTORIZADO' | 'RECHAZADO'
}

export type AppSettings = {
  supportPhone: string
  updatedAt?: string | null
}

export type ActivityEvent = {
  id: string
  title: string
  detail: string
  meta: string
  createdAt: string
  tone: 'success' | 'warning' | 'danger'
}
