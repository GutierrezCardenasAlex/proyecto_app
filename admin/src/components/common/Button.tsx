import type { ButtonHTMLAttributes, PropsWithChildren } from 'react'

type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'success'

type Props = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant
}

export default function Button({ children, className = '', variant = 'primary', ...props }: PropsWithChildren<Props>) {
  const variantClass =
    variant === 'secondary'
      ? 'secondary-button'
      : variant === 'danger'
        ? 'danger-button'
        : variant === 'success'
          ? 'success-button'
          : 'primary-button'

  return (
    <button className={`${variantClass} ${className}`.trim()} {...props}>
      {children}
    </button>
  )
}
