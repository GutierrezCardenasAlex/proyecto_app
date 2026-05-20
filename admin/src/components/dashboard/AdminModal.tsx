import type { PropsWithChildren, ReactNode } from 'react'
import Modal from '../common/Modal'

type Props = {
  open: boolean
  title: string
  subtitle?: string
  size?: 'md' | 'lg' | 'xl'
  actions?: ReactNode
  onClose: () => void
  className?: string
  bodyClassName?: string
}

export default function AdminModal({ children, ...props }: PropsWithChildren<Props>) {
  return <Modal fullscreenMobile size="xl" {...props}>{children}</Modal>
}
