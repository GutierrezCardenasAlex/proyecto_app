import { createContext, useMemo, useState, type PropsWithChildren } from 'react'
import type { AdminProfile } from '../types/admin'

type SessionType = 'admin' | 'monitor' | ''

type AuthContextValue = {
  token: string
  gateToken: string
  adminProfile: AdminProfile | null
  sessionType: SessionType
  hasAccessGate: boolean
  isAuthenticated: boolean
  isAdminSession: boolean
  isMonitorSession: boolean
  setAccessGateToken: (token: string) => void
  setAuthenticatedSession: (token: string, admin: AdminProfile, sessionType?: Exclude<SessionType, ''>) => void
  setAdminProfile: (admin: AdminProfile | null) => void
  logout: () => void
  logoutMonitor: () => void
  clearAccessGate: () => void
}

const SESSION_TOKEN_KEY = 'session_token'
const SESSION_TYPE_KEY = 'session_type'
const SESSION_PROFILE_KEY = 'session_profile'
const ACCESS_GATE_KEY = 'access_gate_token'

export const AuthContext = createContext<AuthContextValue | null>(null)

function resolveInitialToken() {
  return localStorage.getItem(SESSION_TOKEN_KEY) ?? localStorage.getItem('admin_token') ?? ''
}

function resolveInitialGateToken() {
  return localStorage.getItem(ACCESS_GATE_KEY) ?? ''
}

function resolveInitialSessionType() {
  const persisted = localStorage.getItem(SESSION_TYPE_KEY)
  if (persisted === 'admin' || persisted === 'monitor') {
    return persisted
  }
  return localStorage.getItem('admin_token') ? 'admin' : ''
}

function resolveInitialProfile() {
  const raw = localStorage.getItem(SESSION_PROFILE_KEY) ?? localStorage.getItem('admin_profile')
  return raw ? (JSON.parse(raw) as AdminProfile) : null
}

export function AuthProvider({ children }: PropsWithChildren) {
  const [token, setToken] = useState(resolveInitialToken)
  const [gateToken, setGateTokenState] = useState(resolveInitialGateToken)
  const [sessionType, setSessionType] = useState<SessionType>(resolveInitialSessionType)
  const [adminProfile, setAdminProfileState] = useState<AdminProfile | null>(resolveInitialProfile)

  const clearAll = () => {
    localStorage.removeItem('admin_token')
    localStorage.removeItem('admin_profile')
    localStorage.removeItem(SESSION_TOKEN_KEY)
    localStorage.removeItem(SESSION_PROFILE_KEY)
    localStorage.removeItem(SESSION_TYPE_KEY)
    localStorage.removeItem(ACCESS_GATE_KEY)
    setToken('')
    setGateTokenState('')
    setSessionType('')
    setAdminProfileState(null)
  }

  const value = useMemo<AuthContextValue>(
    () => ({
      token,
      gateToken,
      adminProfile,
      sessionType,
      hasAccessGate: gateToken.length > 0,
      isAuthenticated: token.length > 0,
      isAdminSession: token.length > 0 && sessionType === 'admin',
      isMonitorSession: token.length > 0 && sessionType === 'monitor',
      setAccessGateToken: (nextGateToken) => {
        localStorage.setItem(ACCESS_GATE_KEY, nextGateToken)
        setGateTokenState(nextGateToken)
      },
      setAuthenticatedSession: (nextToken, admin, nextSessionType = 'admin') => {
        localStorage.setItem(SESSION_TOKEN_KEY, nextToken)
        localStorage.setItem(SESSION_PROFILE_KEY, JSON.stringify(admin))
        localStorage.setItem(SESSION_TYPE_KEY, nextSessionType)
        setToken(nextToken)
        setSessionType(nextSessionType)
        setAdminProfileState(admin)
      },
      setAdminProfile: (admin) => {
        if (admin) {
          localStorage.setItem(SESSION_PROFILE_KEY, JSON.stringify(admin))
        } else {
          localStorage.removeItem(SESSION_PROFILE_KEY)
        }
        setAdminProfileState(admin)
      },
      logout: clearAll,
      logoutMonitor: clearAll,
      clearAccessGate: clearAll,
    }),
    [adminProfile, gateToken, sessionType, token],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
