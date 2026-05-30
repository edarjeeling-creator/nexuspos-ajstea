import { create } from 'zustand'
import { v4 as uuidv4 } from 'uuid'
import { MenuItem } from '@/lib/db/pos-db'

export interface CartItem extends MenuItem {
  cartItemId: string;
  quantity: number;
  modifiers: any[];
}

interface PosState {
  orderId: string;
  items: CartItem[];
  discount: number;
  taxRate: number;
  addItem: (item: MenuItem) => void;
  removeItem: (cartItemId: string) => void;
  updateQuantity: (cartItemId: string, quantity: number) => void;
  clearCart: () => void;
  subtotal: () => number;
  taxAmount: () => number;
  total: () => number;
}

export const usePosStore = create<PosState>((set, get) => ({
  orderId: uuidv4(), // Local UUID generated immediately for idempotency
  items: [],
  discount: 0,
  taxRate: 0.10, // 10% default for MVP

  addItem: (item) => {
    set((state) => {
      // Simple logic: aggregate by item.id if no modifiers
      const existing = state.items.find(i => i.id === item.id)
      if (existing) {
        return {
          items: state.items.map(i => 
            i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i
          )
        }
      }
      return {
        items: [...state.items, { ...item, cartItemId: uuidv4(), quantity: 1, modifiers: [] }]
      }
    })
  },

  removeItem: (cartItemId) => {
    set((state) => ({
      items: state.items.filter(i => i.cartItemId !== cartItemId)
    }))
  },

  updateQuantity: (cartItemId, quantity) => {
    if (quantity <= 0) {
      get().removeItem(cartItemId);
      return;
    }
    set((state) => ({
      items: state.items.map(i => 
        i.cartItemId === cartItemId ? { ...i, quantity } : i
      )
    }))
  },

  clearCart: () => {
    // Generate a fresh UUID for the next order
    set({ items: [], discount: 0, orderId: uuidv4() }) 
  },

  subtotal: () => {
    return get().items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
  },

  taxAmount: () => {
    const taxable = Math.max(0, get().subtotal() - get().discount);
    return taxable * get().taxRate;
  },

  total: () => {
    const sub = get().subtotal();
    const d = get().discount;
    return Math.max(0, sub - d) + get().taxAmount();
  }
}))
