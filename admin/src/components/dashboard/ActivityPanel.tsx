import Card from '../cards/Card'
import type { ActivityEvent } from '../../types/admin'
import { formatDateTime } from '../../utils/helpers'

export default function ActivityPanel({ events }: { events: ActivityEvent[] }) {
  return (
    <Card title="Actividad reciente" subtitle={`${events.length} eventos`}>
      <div className="activity-list">
        {events.map((event) => (
          <article key={event.id} className="activity-card">
            <span className={`status-pill ${event.tone}`}>{event.meta}</span>
            <strong>{event.title}</strong>
            <p>{event.detail}</p>
            <small>{formatDateTime(event.createdAt)}</small>
          </article>
        ))}
      </div>
    </Card>
  )
}
