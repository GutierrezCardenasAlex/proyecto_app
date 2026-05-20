import type { PropsWithChildren, ReactNode } from 'react'

type Props = {
  open: boolean
  title: string
  subtitle?: string
  size?: 'md' | 'lg' | 'xl'
  fullscreenMobile?: boolean
  actions?: ReactNode
  className?: string
  bodyClassName?: string
  onClose: () => void
}

function CloseIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M18 6 6 18" />
      <path d="m6 6 12 12" />
    </svg>
  )
}

export default function Modal({
  open,
  title,
  subtitle,
  size = 'lg',
  fullscreenMobile = true,
  actions,
  className = '',
  bodyClassName = '',
  onClose,
  children,
}: PropsWithChildren<Props>) {
  if (!open) {
    return null
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className={`modal-shell modal-size-${size} ${fullscreenMobile ? 'modal-mobile-full' : ''} ${className}`.trim()}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="modal-header">
          <div className="modal-title-wrap">
            <h2>{title}</h2>
            {subtitle && <p>{subtitle}</p>}
          </div>
          <button type="button" className="modal-close-button" onClick={onClose} aria-label="Cerrar modal">
            <CloseIcon />
          </button>
        </div>

        <div className={`modal-body ${bodyClassName}`.trim()}>{children}</div>

        {actions && <div className="modal-footer">{actions}</div>}
      </div>
    </div>
  )
}
