type Props = {
  title: string
  subtitle: string
  status: 'Disponible' | 'En viaje' | 'Desconectado'
  meta?: string
  onClick?: () => void
  active?: boolean
}

export default function VehicleStatusCard({ title, subtitle, status, meta, onClick, active = false }: Props) {
  const toneClass =
    status === 'Disponible' ? 'success' : status === 'En viaje' ? 'warning' : 'danger'

  return (
    <button type="button" className={active ? 'saas-vehicle-card active' : 'saas-vehicle-card'} onClick={onClick}>
      <div className="saas-vehicle-copy">
        <strong>{title}</strong>
        <span>{subtitle}</span>
      </div>
      <div className="saas-vehicle-meta">
        <span className={`status-pill ${toneClass}`}>{status}</span>
        {meta && <small>{meta}</small>}
      </div>
    </button>
  )
}
