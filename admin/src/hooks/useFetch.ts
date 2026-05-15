import { useEffect, useState } from 'react'

export function useFetch<T>(loader: () => Promise<T>, immediate = true) {
  const [data, setData] = useState<T | null>(null)
  const [loading, setLoading] = useState(immediate)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!immediate) {
      return
    }

    let mounted = true
    setLoading(true)
    loader()
      .then((payload) => {
        if (mounted) {
          setData(payload)
          setError(null)
        }
      })
      .catch((fetchError) => {
        if (mounted) {
          setError(fetchError instanceof Error ? fetchError.message : 'No se pudo cargar la informacion.')
        }
      })
      .finally(() => {
        if (mounted) {
          setLoading(false)
        }
      })

    return () => {
      mounted = false
    }
  }, [immediate, loader])

  return { data, loading, error, setData, setError }
}
