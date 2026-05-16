import { API_BASE } from '../utils/constants'
import { apiRequest } from './api'
import type { AccessGateResponse, AdminLoginResponse, AdminOtpRequestResponse, AuthSessionResponse } from '../types/admin'

const gateHeaders = (gateToken: string) => ({
  'Content-Type': 'application/json',
  'X-Access-Gate': gateToken,
})

export function verifyAccessGate(superAdminKey: string) {
  return apiRequest<AccessGateResponse>(`${API_BASE}/auth/admin/access/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ superAdminKey }),
  })
}

export function loginAdmin(username: string, password: string, gateToken: string) {
  return apiRequest<AdminLoginResponse>(`${API_BASE}/auth/admin/login`, {
    method: 'POST',
    headers: gateHeaders(gateToken),
    body: JSON.stringify({ username, password }),
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
