import type { PropsWithChildren } from 'react'

type Props = {
  title?: string
  subtitle?: string
  actions?: React.ReactNode
  className?: string
}

export default function Card({ title, subtitle, actions, className = '', children }: PropsWithChildren<Props>) {
  return (
    <section className={`panel ${className}`.trim()}>
      {(title || subtitle || actions) && (
        <div className="panel-header">
          <div>
            {title && <h2>{title}</h2>}
            {subtitle && <span>{subtitle}</span>}
          </div>
          {actions}
        </div>
      )}
      {children}
    </section>
  )
}
