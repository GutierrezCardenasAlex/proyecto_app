export default function Loader({ label = 'Cargando...' }: { label?: string }) {
  return (
    <div className="loader-box">
      <div className="loader-dot" />
      <span>{label}</span>
    </div>
  )
}
