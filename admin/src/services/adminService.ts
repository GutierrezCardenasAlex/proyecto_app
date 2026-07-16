import type {
  AppSettings,
  Dashboard,
  DeviceRow,
  Driver,
  DriverPerformanceResponse,
  DriverTripsResponse,
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
import { API_BASE } from '../utils/constants'
import { apiRequest } from './api'

const authJsonHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
  'Content-Type': 'application/json',
})

const authHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
})

export const adminService = {
  getDashboard: (token: string) => apiRequest<Dashboard>(`${API_BASE}/admin/dashboard`, { headers: authHeaders(token) }),
  getLiveDrivers: (token: string) => apiRequest<Driver[]>(`${API_BASE}/admin/drivers/live`, { headers: authHeaders(token) }),
  getActiveTrips: (token: string) => apiRequest<Trip[]>(`${API_BASE}/admin/active-trips`, { headers: authHeaders(token) }),
  getPendingDrivers: (token: string) =>
    apiRequest<PendingDriverAccessRow[]>(`${API_BASE}/admin/drivers/pending-access`, { headers: authHeaders(token) }),
  getPendingDevices: (token: string) => apiRequest<DeviceRow[]>(`${API_BASE}/admin/devices/pending`, { headers: authHeaders(token) }),
  getDevices: (token: string) => apiRequest<DeviceRow[]>(`${API_BASE}/admin/devices`, { headers: authHeaders(token) }),
  getUsers: (token: string) => apiRequest<ManagedUserRow[]>(`${API_BASE}/admin/users`, { headers: authHeaders(token) }),
  getPromoSettings: (token: string) => apiRequest<PromoSettings>(`${API_BASE}/admin/promotions/settings`, { headers: authHeaders(token) }),
  getAppSettings: (token: string) => apiRequest<AppSettings>(`${API_BASE}/admin/settings/support-phone`, { headers: authHeaders(token) }),
  getSupportReports: (token: string) =>
    apiRequest<SupportReport[]>(`${API_BASE}/admin/support/reports/all`, { headers: authHeaders(token) }),
  getDriverPerformance: (token: string, range: PerformanceRange) =>
    apiRequest<DriverPerformanceResponse>(`${API_BASE}/admin/drivers/performance?range=${range}`, { headers: authHeaders(token) }),
  getOfflineStatus: (token: string) => apiRequest<OfflineMapStatus>(`${API_BASE}/admin/offline/status`, { headers: authHeaders(token) }),
  getDriverTrips: (token: string, driverId: string, range: PerformanceRange) =>
    apiRequest<DriverTripsResponse>(`${API_BASE}/admin/drivers/${driverId}/trips?range=${range}`, { headers: authHeaders(token) }),
  getUserHistory: (token: string, user: UserSummary) =>
    apiRequest<DeviceRow[]>(`${API_BASE}/admin/devices/user/${user.user_id}/history`, { headers: authHeaders(token) }),
  updateDriverAccess: (token: string, driverId: string, status: 'AUTORIZADO' | 'RECHAZADO', note?: string) =>
    apiRequest(`${API_BASE}/admin/drivers/${driverId}/access`, {
      method: 'POST',
      headers: authJsonHeaders(token),
      body: JSON.stringify({ status, note }),
    }),
  updateDeviceStatus: (token: string, deviceId: number, status: 'AUTORIZADO' | 'RECHAZADO') =>
    apiRequest(`${API_BASE}/admin/devices/${deviceId}/status`, {
      method: 'POST',
      headers: authJsonHeaders(token),
      body: JSON.stringify({ status }),
    }),
  replaceDevice: (token: string, deviceId: number) =>
    apiRequest(`${API_BASE}/admin/devices/${deviceId}/replace`, {
      method: 'POST',
      headers: authHeaders(token),
    }),
  updatePromoStatus: (token: string, payload: { enabled: boolean; cycleLength: number; rewardCredits: number }) =>
    apiRequest<{ message: string; settings: PromoSettings }>(`${API_BASE}/admin/promotions/settings`, {
      method: 'POST',
      headers: authJsonHeaders(token),
      body: JSON.stringify(payload),
    }),
  updateSupportPhone: (token: string, supportPhone: string) =>
    apiRequest<AppSettings>(`${API_BASE}/admin/settings/support-phone`, {
      method: 'POST',
      headers: authJsonHeaders(token),
      body: JSON.stringify({ supportPhone }),
    }),
  sendNotification: (
    token: string,
    payload: { audience: 'all' | 'passengers' | 'drivers' | 'user'; phone?: string; kind: NotificationKind; title: string; message: string },
  ) =>
    apiRequest(`${API_BASE}/admin/notifications/send`, {
      method: 'POST',
      headers: authJsonHeaders(token),
      body: JSON.stringify(payload),
    }),
  changeUserPhone: (token: string, userId: string, phone: string) =>
    apiRequest<{ user: { phone: string } }>(`${API_BASE}/admin/users/${userId}/change-phone`, {
      method: 'POST',
      headers: authJsonHeaders(token),
      body: JSON.stringify({ phone }),
    }),
}
