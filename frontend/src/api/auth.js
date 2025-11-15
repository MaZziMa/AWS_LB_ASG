import api from './axios'

export const authAPI = {
  login: async (username, password) => {
    const response = await api.post('/auth/login', { username, password })
    return response.data
  },
  
  getCurrentUser: async () => {
    const response = await api.get('/auth/me')
    return response.data
  },
  
  logout: () => {
    // Clear local storage
    localStorage.removeItem('auth-storage')
  }
}
