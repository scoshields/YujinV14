import { create } from 'zustand';
import { User } from '../types';
import { signOut as authSignOut, getCurrentUser, getSession } from '../services/auth';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isInitialized: boolean;
  login: (user: User) => Promise<void>;
  updateUser: (user: User) => void;
  logout: (redirect?: boolean) => Promise<void>;
  initAuth: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isAuthenticated: false,
  isInitialized: false,
  login: async (user) => {
    set({ user, isAuthenticated: true });
  },
  updateUser: (user) => set({ user }),
  logout: async (redirect = true) => {
    await authSignOut();
    set({ user: null, isAuthenticated: false, isInitialized: true });
    if (redirect) {
      window.location.href = '/';
    }
  },
  initAuth: async () => {
    try {
      const session = await getSession();

      if (session) {
        const userData = await getCurrentUser();
        if (userData) {
          set({ user: userData, isAuthenticated: true, isInitialized: true });
          return;
        }
      } else if (window.location.pathname !== '/' && 
                 window.location.pathname !== '/login' && 
                 window.location.pathname !== '/signup') {
        window.location.href = '/';
      } else {
        set({ user: null, isAuthenticated: false, isInitialized: true });
      }
    } catch (error) {
      console.error('Auth initialization error:', error);
      set({ user: null, isAuthenticated: false, isInitialized: true });
      window.location.href = '/';
      throw error;
    }
  },
}));