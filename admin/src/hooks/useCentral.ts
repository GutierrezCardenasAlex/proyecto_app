import { useContext } from 'react'
import { CentralContext } from '../context/CentralContext'

export function useCentral() {
  const context = useContext(CentralContext)
  if (!context) {
    throw new Error('useCentral debe usarse dentro de CentralProvider')
  }
  return context
}
