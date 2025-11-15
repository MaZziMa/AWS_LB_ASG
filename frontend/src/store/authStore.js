import { create } from 'zustand'
import { persist } from 'zustand/middleware'

export const useAuthStore = create(
  persist(
    (set) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      
      login: (userData, accessToken) => {
        set({
          user: userData,
          token: accessToken,
          isAuthenticated: true
        })
      },
      
      logout: () => {
        set({
          user: null,
          token: null,
          isAuthenticated: false
        })
      },
      
      updateUser: (userData) => {
        set({ user: userData })
      }
    }),
    {
      name: 'auth-storage',
    }
  )
)
