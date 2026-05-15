type Props = {
  title: string
  value: string
  change?: string
  tone?: 'accent' | 'success' | 'warning'
  icon?: string
}

export default function MetricCard({ title, value, change, tone = 'accent', icon }: Props) {
  return (
    <article className={`saas-metric-card saas-tone-${tone}`}>
      <div className="saas-metric-top">
        <span className="saas-metric-label">{title}</span>
        {icon && <span className="saas-metric-icon">{icon}</span>}
      </div>
      <strong className="saas-metric-value">{value}</strong>
      <span className="saas-metric-change">{change || 'Actualizado en tiempo real'}</span>
    </article>
  )
}
