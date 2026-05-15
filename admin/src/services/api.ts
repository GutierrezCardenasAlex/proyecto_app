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
        if (payload.trim().startsWith('<')) {
          throw new Error(`La central devolvio HTML en vez de JSON (${response.status}). Revisa proxy, dominio o API.`)
        }
        throw new Error(`La central respondio con un formato no esperado (${response.status}).`)
      }
      throw new Error(payload.message ?? 'No se pudo completar la solicitud.')
    }

    if (!contentType.includes('application/json')) {
      if (typeof payload === 'string' && payload.trim().startsWith('<')) {
        throw new Error('La central devolvio una pagina HTML en vez de datos JSON. Revisa el backend o el proxy.')
      }
      throw new Error('La central respondio con un formato diferente al esperado.')
    }

    return payload as T
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new Error('La central tardo demasiado en responder. Intenta de nuevo.')
    }
    throw error
  } finally {
    window.clearTimeout(timeoutId)
  }
}
