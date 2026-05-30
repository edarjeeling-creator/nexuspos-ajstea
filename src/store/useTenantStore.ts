import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import { Permission } from '@/lib/constants/permissions'

interface TenantState {
  tenantId: string | null;
  outletId: string | null;
  permissions: Permission[];
  setTenant: (tenantId: string, outletId: string, permissions: Permission[]) => void;
  setOutlet: (outletId: string) => void;
  clearTenant: () => void;
}

export const useTenantStore = create<TenantState>()(
  persist(
    (set) => ({
      tenantId: null,
      outletId: null,
      permissions: [],
      setTenant: (tenantId, outletId, permissions) => set({ tenantId, outletId, permissions }),
      setOutlet: (outletId) => set({ outletId }),
      clearTenant: () => set({ tenantId: null, outletId: null, permissions: [] }),
    }),
    {
      name: 'nexuspos-tenant-storage',
      storage: createJSONStorage(() => localStorage),
      // We persist outletId locally for convenience, but future support will 
      // sync this to public.profiles.last_active_outlet_id
      partialize: (state) => ({ outletId: state.outletId }),
    }
  )
)
