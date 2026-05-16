import { HashRouter, Navigate, Outlet, Route, Routes } from 'react-router-dom'
import { AuthProvider } from '../context/AuthContext'
import { CentralProvider } from '../context/CentralContext'
import { useAuth } from '../hooks/useAuth'
import { APP_ROUTES } from '../utils/constants'
import AuthLayout from '../layouts/AuthLayout'
import DashboardLayout from '../layouts/DashboardLayout'
import MonitoringLayout from '../layouts/MonitoringLayout'
import DashboardHome from '../pages/Dashboard/DashboardHome'
import DriversPage from '../pages/Dashboard/Drivers'
import LiveMapPage from '../pages/Dashboard/LiveMap'
import ReportsPage from '../pages/Dashboard/Reports'
import SettingsPage from '../pages/Dashboard/Settings'
import TripsPage from '../pages/Dashboard/Trips'
import DashboardUsersPage from '../pages/Dashboard/Users'
import VehiclesPage from '../pages/Dashboard/Vehicles'
import Login from '../pages/Login/Login'
import MonitoringLogin from '../pages/Monitoring/MonitoringLogin'
import MonitoringMapPage from '../pages/Monitoring/MonitoringMap'
import NotFound from '../pages/NotFound/NotFound'

function ProtectedRoute() {
  const { isAuthenticated } = useAuth()
  return isAuthenticated ? <Outlet /> : <Navigate to={APP_ROUTES.login} replace />
}

function PublicRoute() {
  const { isAuthenticated } = useAuth()
  return isAuthenticated ? <Navigate to={APP_ROUTES.dashboard} replace /> : <Outlet />
}

function MonitoringProtectedRoute() {
  const { isAuthenticated, monitorAuthenticated } = useAuth()
  return isAuthenticated || monitorAuthenticated ? <Outlet /> : <Navigate to={APP_ROUTES.monitoringLogin} replace />
}

function MonitoringPublicRoute() {
  const { isAuthenticated, monitorAuthenticated } = useAuth()
  return isAuthenticated || monitorAuthenticated ? <Navigate to={APP_ROUTES.monitoring} replace /> : <Outlet />
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

        <Route element={<MonitoringPublicRoute />}>
          <Route element={<AuthLayout />}>
            <Route path={APP_ROUTES.monitoringLogin} element={<MonitoringLogin />} />
          </Route>
        </Route>

        <Route element={<MonitoringProtectedRoute />}>
          <Route
            element={
              <CentralProvider>
                <MonitoringLayout />
              </CentralProvider>
            }
          >
            <Route path={APP_ROUTES.monitoring} element={<MonitoringMapPage />} />
          </Route>
        </Route>

        <Route element={<ProtectedRoute />}>
          <Route
            element={
              <CentralProvider>
                <DashboardLayout />
              </CentralProvider>
            }
          >
            <Route path="/" element={<Navigate to={APP_ROUTES.dashboard} replace />} />
            <Route path={APP_ROUTES.dashboard} element={<DashboardHome />} />
            <Route path={APP_ROUTES.dashboardMap} element={<LiveMapPage />} />
            <Route path={APP_ROUTES.dashboardDrivers} element={<DriversPage />} />
            <Route path={APP_ROUTES.dashboardVehicles} element={<VehiclesPage />} />
            <Route path={APP_ROUTES.dashboardTrips} element={<TripsPage />} />
            <Route path={APP_ROUTES.dashboardUsers} element={<DashboardUsersPage />} />
            <Route path={APP_ROUTES.dashboardReports} element={<ReportsPage />} />
            <Route path={APP_ROUTES.dashboardSettings} element={<SettingsPage />} />

            <Route path={APP_ROUTES.overview} element={<Navigate to={APP_ROUTES.dashboard} replace />} />
            <Route path={APP_ROUTES.map} element={<Navigate to={APP_ROUTES.dashboardMap} replace />} />
            <Route path={APP_ROUTES.users} element={<Navigate to={APP_ROUTES.dashboardUsers} replace />} />
            <Route path={APP_ROUTES.activity} element={<Navigate to={APP_ROUTES.dashboardReports} replace />} />
            <Route path={APP_ROUTES.stats} element={<Navigate to={APP_ROUTES.dashboardReports} replace />} />
            <Route path={APP_ROUTES.support} element={<Navigate to={APP_ROUTES.dashboardReports} replace />} />
            <Route path={APP_ROUTES.devices} element={<Navigate to={APP_ROUTES.dashboardVehicles} replace />} />
            <Route path={APP_ROUTES.profile} element={<Navigate to={APP_ROUTES.dashboardSettings} replace />} />
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
