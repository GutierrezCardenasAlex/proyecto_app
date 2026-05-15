import { createContext, useMemo, useState, type PropsWithChildren } from 'react'
import type { AdminProfile } from '../types/admin'

type AuthContextValue = {
  token: string
  adminProfile: AdminProfile | null
  isAuthenticated: boolean
  setAuthenticatedSession: (token: string, admin: AdminProfile) => void
  setAdminProfile: (admin: AdminProfile | null) => void
  logout: () => void
}

export const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: PropsWithChildren) {
  const [token, setToken] = useState(localStorage.getItem('admin_token') ?? '')
  const [adminProfile, setAdminProfileState] = useState<AdminProfile | null>(() => {
    const raw = localStorage.getItem('admin_profile')
    return raw ? (JSON.parse(raw) as AdminProfile) : null
  })

  const value = useMemo<AuthContextValue>(
    () => ({
      token,
      adminProfile,
      isAuthenticated: token.length > 0,
      setAuthenticatedSession: (nextToken, admin) => {
        localStorage.setItem('admin_token', nextToken)
        localStorage.setItem('admin_profile', JSON.stringify(admin))
        setToken(nextToken)
        setAdminProfileState(admin)
      },
      setAdminProfile: (admin) => {
        if (admin) {
          localStorage.setItem('admin_profile', JSON.stringify(admin))
        } else {
          localStorage.removeItem('admin_profile')
        }
        setAdminProfileState(admin)
      },
      logout: () => {
        localStorage.removeItem('admin_token')
        localStorage.removeItem('admin_profile')
        setToken('')
        setAdminProfileState(null)
      },
    }),
    [adminProfile, token],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
