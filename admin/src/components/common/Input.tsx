import type { InputHTMLAttributes, TextareaHTMLAttributes } from 'react'

type SharedProps = {
  label?: string
  multiline?: boolean
}

type Props = SharedProps & InputHTMLAttributes<HTMLInputElement> & TextareaHTMLAttributes<HTMLTextAreaElement>

export default function Input({ label, className = '', multiline = false, ...props }: Props) {
  const field = multiline ? (
    <textarea className={`note-input ${className}`.trim()} {...(props as TextareaHTMLAttributes<HTMLTextAreaElement>)} />
  ) : (
    <input className={className} {...(props as InputHTMLAttributes<HTMLInputElement>)} />
  )

  if (!label) {
    return field
  }

  return (
    <label className="auth-form">
      <span>{label}</span>
      {field}
    </label>
  )
}
