import { API_BASE } from '../utils/constants'
import { apiRequest } from './api'
import type { AdminLoginResponse, AdminOtpRequestResponse, AuthSessionResponse } from '../types/admin'

export function loginAdmin(username: string, password: string, superAdminKey: string) {
  return apiRequest<AdminLoginResponse>(`${API_BASE}/auth/admin/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password, superAdminKey }),
  })
}

export function loginMonitor(username: string, password: string) {
  return apiRequest<AuthSessionResponse>(`${API_BASE}/auth/admin/monitor/login`, {
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
  return apiRequest<AuthSessionResponse>(`${API_BASE}/auth/admin/otp/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone, otp }),
  })
}
