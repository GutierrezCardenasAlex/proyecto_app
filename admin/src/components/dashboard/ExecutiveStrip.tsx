import Card from '../cards/Card'

type Signal = { label: string; value: string; tone: 'success' | 'warning' | 'danger' }

export default function ExecutiveStrip({ title, subtitle, signals }: { title: string; subtitle: string; signals: Signal[] }) {
  return (
    <Card title={title} subtitle={subtitle} className="executive-strip">
      <div className="mini-stats-grid executive-grid">
        {signals.map((signal) => (
          <article key={signal.label} className="mini-stat-card executive-mini-card">
            <span className={`status-pill ${signal.tone}`}>{signal.label}</span>
            <strong>{signal.value}</strong>
          </article>
        ))}
      </div>
    </Card>
  )
}
