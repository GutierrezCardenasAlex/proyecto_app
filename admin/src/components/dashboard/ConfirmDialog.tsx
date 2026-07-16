import Button from '../common/Button'
import AdminModal from './AdminModal'
import type { ReactNode } from 'react'

type Props = {
  open: boolean
  title: string
  message: string
  children?: ReactNode
  confirmLabel?: string
  cancelLabel?: string
  tone?: 'danger' | 'warning'
  loading?: boolean
  confirmDisabled?: boolean
  onCancel: () => void
  onConfirm: () => void
}

export default function ConfirmDialog({
  open,
  title,
  message,
  children,
  confirmLabel = 'Confirmar',
  cancelLabel = 'Cancelar',
  tone = 'danger',
  loading = false,
  confirmDisabled = false,
  onCancel,
  onConfirm,
}: Props) {
  return (
    <AdminModal
      open={open}
      onClose={onCancel}
      title={title}
      subtitle="Esta accion impacta datos administrativos. Revisa antes de continuar."
      size="md"
      actions={
        <>
          <Button variant="secondary" onClick={onCancel} disabled={loading}>
            {cancelLabel}
          </Button>
          <Button variant={tone === 'warning' ? 'secondary' : 'danger'} onClick={onConfirm} disabled={loading || confirmDisabled}>
            {loading ? 'Procesando...' : confirmLabel}
          </Button>
        </>
      }
    >
      <div className={`confirm-dialog ${tone}`}>
        <div className="confirm-dialog-icon">{tone === 'danger' ? '!' : '?'}</div>
        <div>
          <strong>Confirmacion obligatoria</strong>
          <p>{message}</p>
        </div>
      </div>
      {children}
    </AdminModal>
  )
}
