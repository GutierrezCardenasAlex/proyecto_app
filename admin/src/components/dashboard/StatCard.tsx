type Props = {
  label: string
  value: string
  detail?: string
  icon?: string
  tone?: 'accent' | 'success' | 'warning' | 'neutral'
}

export default function StatCard({ label, value, detail, icon, tone = 'accent' }: Props) {
  return (
    <article className={`admin-stat-card ${tone}`}>
      <div className="admin-stat-card__top">
        <span className="admin-stat-card__label">{label}</span>
        {icon && <span className="admin-stat-card__icon">{icon}</span>}
      </div>
      <strong className="admin-stat-card__value">{value}</strong>
      {detail && <p className="admin-stat-card__detail">{detail}</p>}
    </article>
  )
}
