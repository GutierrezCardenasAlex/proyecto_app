import type { PropsWithChildren } from 'react'

type Props = {
  open: boolean
  title: string
  onClose: () => void
}

export default function Modal({ open, title, onClose, children }: PropsWithChildren<Props>) {
  if (!open) {
    return null
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-shell panel" onClick={(event) => event.stopPropagation()}>
        <div className="panel-header">
          <h2>{title}</h2>
          <button className="secondary-button" onClick={onClose}>
            Cerrar
          </button>
        </div>
        {children}
      </div>
    </div>
  )
}
