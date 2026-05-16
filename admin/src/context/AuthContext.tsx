import { createContext, useMemo, useState, type PropsWithChildren } from 'react'
import type { AdminProfile } from '../types/admin'

type SessionType = 'admin' | 'monitor' | ''

type AuthContextValue = {
  token: string
  adminProfile: AdminProfile | null
  sessionType: SessionType
  isAuthenticated: boolean
  isAdminSession: boolean
  isMonitorSession: boolean
  setAuthenticatedSession: (token: string, admin: AdminProfile, sessionType?: Exclude<SessionType, ''>) => void
  setAdminProfile: (admin: AdminProfile | null) => void
  logout: () => void
  logoutMonitor: () => void
}

const SESSION_TOKEN_KEY = 'session_token'
const SESSION_TYPE_KEY = 'session_type'
const SESSION_PROFILE_KEY = 'session_profile'

export const AuthContext = createContext<AuthContextValue | null>(null)

function resolveInitialToken() {
  return localStorage.getItem(SESSION_TOKEN_KEY) ?? localStorage.getItem('admin_token') ?? ''
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
  const [sessionType, setSessionType] = useState<SessionType>(resolveInitialSessionType)
  const [adminProfile, setAdminProfileState] = useState<AdminProfile | null>(resolveInitialProfile)

  const clearSession = () => {
    localStorage.removeItem('admin_token')
    localStorage.removeItem('admin_profile')
    localStorage.removeItem('monitor_session')
    localStorage.removeItem(SESSION_TOKEN_KEY)
    localStorage.removeItem(SESSION_PROFILE_KEY)
    localStorage.removeItem(SESSION_TYPE_KEY)
    setToken('')
    setSessionType('')
    setAdminProfileState(null)
  }

  const value = useMemo<AuthContextValue>(
    () => ({
      token,
      adminProfile,
      sessionType,
      isAuthenticated: token.length > 0,
      isAdminSession: token.length > 0 && sessionType === 'admin',
      isMonitorSession: token.length > 0 && sessionType === 'monitor',
      setAuthenticatedSession: (nextToken, admin, nextSessionType = 'admin') => {
        localStorage.setItem(SESSION_TOKEN_KEY, nextToken)
        localStorage.setItem(SESSION_PROFILE_KEY, JSON.stringify(admin))
        localStorage.setItem(SESSION_TYPE_KEY, nextSessionType)
        localStorage.removeItem('monitor_session')
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
      logout: clearSession,
      logoutMonitor: clearSession,
    }),
    [adminProfile, sessionType, token],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
