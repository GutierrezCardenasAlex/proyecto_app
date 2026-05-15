import type { ManagedUserForm, ManagedUserRow } from '../types/admin'
import { API_BASE } from '../utils/constants'
import { apiRequest } from './api'

const authJsonHeaders = (token: string) => ({
  Authorization: `Bearer ${token}`,
  'Content-Type': 'application/json',
})

export const userService = {
  createUser: (token: string, payload: ManagedUserForm) =>
    apiRequest<{ message: string; user: ManagedUserRow }>(`${API_BASE}/admin/users`, {
      method: 'POST',
      headers: authJsonHeaders(token),
      body: JSON.stringify(payload),
    }),
  updateUser: (token: string, userId: string, payload: ManagedUserForm) =>
    apiRequest<{ message: string; user: ManagedUserRow }>(`${API_BASE}/admin/users/${userId}`, {
      method: 'PATCH',
      headers: authJsonHeaders(token),
      body: JSON.stringify(payload),
    }),
  deleteUser: (token: string, userId: string) =>
    apiRequest<{ message: string }>(`${API_BASE}/admin/users/${userId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    }),
}
