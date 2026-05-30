import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

interface ShiftState {
  shiftId: string | null;
  cashRegisterId: string | null;
  cashRegisterName: string | null;
  isOpen: boolean;
  openedAt: string | null;
  openShift: (registerId: string, name: string, shiftId: string) => void;
  closeShift: () => void;
}

export const useShiftStore = create<ShiftState>()(
  persist(
    (set) => ({
      shiftId: null,
      cashRegisterId: null,
      cashRegisterName: null,
      isOpen: false,
      openedAt: null,
      openShift: (registerId, name, shiftId) => set({ 
        cashRegisterId: registerId, 
        cashRegisterName: name, 
        shiftId,
        isOpen: true, 
        openedAt: new Date().toISOString() 
      }),
      closeShift: () => set({ 
        shiftId: null, 
        isOpen: false, 
        openedAt: null 
      }),
    }),
    {
      name: 'nexuspos-shift-storage',
      storage: createJSONStorage(() => localStorage),
    }
  )
)
