import ExecutiveStrip from '../../components/dashboard/ExecutiveStrip'
import OverviewSections from '../../components/dashboard/OverviewSections'
import PageHero from '../../components/dashboard/PageHero'
import { useCentral } from '../../hooks/useCentral'
import { VIEW_DESCRIPTIONS, VIEW_LABELS } from '../../utils/constants'

export default function Home() {
  const central = useCentral()

  return (
    <>
      <PageHero
        eyebrow="Central RAPIGO / Potosi"
        title={VIEW_LABELS.overview}
        description={VIEW_DESCRIPTIONS.overview}
        metrics={[
          { label: 'Flota visible', value: `${central.drivers.length}` },
          { label: 'Viajes activos', value: `${central.dashboard.activeTrips}` },
          { label: 'Pendientes', value: `${central.pendingDevices.length + central.pendingDrivers.length}` },
          { label: 'Soporte abierto', value: `${central.supportSummary.open}` },
        ]}
      />
      <ExecutiveStrip
        title="Resumen ejecutivo"
        subtitle={`Central activa${central.lastUpdatedAt ? ` · ${central.lastUpdatedAt}` : ''}`}
        signals={central.executiveSignals}
      />
      <OverviewSections
        promoSettings={central.promoSettings}
        trips={central.trips}
        pendingDrivers={central.pendingDrivers}
        pendingDevices={central.pendingDevices}
        loading={central.loading}
        driverAccessNote={central.driverAccessNote}
        supportReports={central.supportReports}
        notificationAudience={central.notificationAudience}
        notificationPhone={central.notificationPhone}
        notificationTitle={central.notificationTitle}
        notificationMessage={central.notificationMessage}
        notificationKind={central.notificationKind}
        onDriverAccessNoteChange={central.setDriverAccessNote}
        onUpdatePromoStatus={central.updatePromoStatus}
        onUpdateDriverAccess={central.updateDriverAccess}
        onUpdateDeviceStatus={central.updateDeviceStatus}
        onLoadHistory={central.loadUserHistory}
        onNotificationAudienceChange={central.setNotificationAudience}
        onNotificationPhoneChange={central.setNotificationPhone}
        onNotificationTitleChange={central.setNotificationTitle}
        onNotificationMessageChange={central.setNotificationMessage}
        onNotificationKindChange={central.setNotificationKind}
        onSendNotification={central.sendAdminNotification}
      />
    </>
  )
}
