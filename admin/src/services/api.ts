export async function apiRequest<T>(url: string, init?: RequestInit, timeoutMs = 10000): Promise<T> {
  const controller = new AbortController()
  const timeoutId = window.setTimeout(() => controller.abort(), timeoutMs)

  try {
    const response = await fetch(url, {
      ...init,
      signal: controller.signal,
    })

    const contentType = response.headers.get('content-type') || ''
    const payload = contentType.includes('application/json') ? await response.json() : await response.text()

    if (!response.ok) {
      if (typeof payload === 'string') {
        throw new Error('La central respondio con un formato no esperado.')
      }
      throw new Error(payload.message ?? 'No se pudo completar la solicitud.')
    }

    return payload as T
  } finally {
    window.clearTimeout(timeoutId)
  }
}
