import { API_BASE } from '../utils/constants'
import { apiRequest } from './api'
import type { AdminLoginResponse, AdminOtpRequestResponse, AdminProfile } from '../types/admin'

export function loginAdmin(username: string, password: string) {
  return apiRequest<AdminLoginResponse>(`${API_BASE}/auth/admin/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  })
}

export function requestAdminOtp(phone: string) {
  return apiRequest<AdminOtpRequestResponse>(`${API_BASE}/auth/admin/otp/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone }),
  })
}

export function verifyAdminOtp(phone: string, otp: string) {
  return apiRequest<{ token: string; admin: AdminProfile }>(`${API_BASE}/auth/admin/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone, otp }),
  })
}
