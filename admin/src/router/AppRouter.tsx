import { HashRouter, Navigate, Outlet, Route, Routes } from 'react-router-dom'
import { AuthProvider } from '../context/AuthContext'
import { CentralProvider } from '../context/CentralContext'
import { useAuth } from '../hooks/useAuth'
import { APP_ROUTES } from '../utils/constants'
import AuthLayout from '../layouts/AuthLayout'
import MainLayout from '../layouts/MainLayout'
import ActivityPage from '../pages/Activity/Activity'
import Dashboard from '../pages/Dashboard/Dashboard'
import DevicesPage from '../pages/Devices/Devices'
import Home from '../pages/Home/Home'
import Login from '../pages/Login/Login'
import MapPage from '../pages/Map/Map'
import NotFound from '../pages/NotFound/NotFound'
import ProfilePage from '../pages/Profile/Profile'
import StatisticsPage from '../pages/Statistics/Statistics'
import SupportPage from '../pages/Support/Support'
import UsersPage from '../pages/Users/Users'

function ProtectedRoute() {
  const { isAuthenticated } = useAuth()
  return isAuthenticated ? <Outlet /> : <Navigate to={APP_ROUTES.login} replace />
}

function PublicRoute() {
  const { isAuthenticated } = useAuth()
  return isAuthenticated ? <Navigate to={APP_ROUTES.overview} replace /> : <Outlet />
}

function RouterTree() {
  return (
    <HashRouter>
      <Routes>
        <Route element={<PublicRoute />}>
          <Route element={<AuthLayout />}>
            <Route path={APP_ROUTES.login} element={<Login />} />
          </Route>
        </Route>

        <Route element={<ProtectedRoute />}>
          <Route
            element={
              <CentralProvider>
                <MainLayout />
              </CentralProvider>
            }
          >
            <Route path="/" element={<Navigate to={APP_ROUTES.overview} replace />} />
            <Route path={APP_ROUTES.dashboard} element={<Dashboard />} />
            <Route path={APP_ROUTES.overview} element={<Home />} />
            <Route path={APP_ROUTES.map} element={<MapPage />} />
            <Route path={APP_ROUTES.users} element={<UsersPage />} />
            <Route path={APP_ROUTES.activity} element={<ActivityPage />} />
            <Route path={APP_ROUTES.stats} element={<StatisticsPage />} />
            <Route path={APP_ROUTES.support} element={<SupportPage />} />
            <Route path={APP_ROUTES.devices} element={<DevicesPage />} />
            <Route path={APP_ROUTES.profile} element={<ProfilePage />} />
          </Route>
        </Route>

        <Route path="*" element={<NotFound />} />
      </Routes>
    </HashRouter>
  )
}

export default function AppRouter() {
  return (
    <AuthProvider>
      <RouterTree />
    </AuthProvider>
  )
}
