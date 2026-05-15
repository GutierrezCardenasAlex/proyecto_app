type Props = {
  eyebrow: string
  title: string
  description: string
  metrics: Array<{ label: string; value: string }>
}

export default function PageHero({ eyebrow, title, description, metrics }: Props) {
  return (
    <section className="hero-panel dashboard-hero">
      <div>
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p className="subtitle">{description}</p>
      </div>
      <div className="stats">
        {metrics.map((metric) => (
          <article key={metric.label}>
            <span>{metric.label}</span>
            <strong>{metric.value}</strong>
          </article>
        ))}
      </div>
    </section>
  )
}
