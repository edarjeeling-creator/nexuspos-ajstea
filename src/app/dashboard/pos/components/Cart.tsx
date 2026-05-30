'use client'

import { usePosStore } from '@/store/usePosStore'
import { Button } from '@/components/ui/button'
import { Trash2, Plus, Minus, CreditCard, Banknote, ShoppingCart } from 'lucide-react'
import { useState } from 'react'
import { CheckoutModal } from './CheckoutModal'

export function Cart() {
  const { items, updateQuantity, removeItem, clearCart, subtotal, taxAmount, total } = usePosStore()
  
  const [checkoutMethod, setCheckoutMethod] = useState<'CASH' | 'CARD' | null>(null)

  return (
    <>
      <div className="flex flex-col h-full bg-white dark:bg-slate-900 border-l dark:border-slate-800 w-full lg:w-[400px] shadow-xl shrink-0">
        {/* Header */}
        <div className="p-4 border-b dark:border-slate-800 flex justify-between items-center bg-slate-50/50 dark:bg-slate-900/50">
          <h2 className="font-semibold text-lg flex items-center gap-2">
            Current Order
            <span className="bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-300 px-2 py-0.5 rounded-full text-xs font-bold">
              {items.reduce((acc, item) => acc + item.quantity, 0)}
            </span>
          </h2>
          <Button variant="ghost" size="icon" onClick={clearCart} className="text-slate-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-950/50">
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>

        {/* Item List */}
        <div className="flex-1 overflow-y-auto p-4 space-y-3">
          {items.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-slate-400 gap-4">
              <div className="h-16 w-16 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center">
                <ShoppingCart className="h-8 w-8 text-slate-300 dark:text-slate-600" />
              </div>
              <p className="text-sm font-medium">Cart is empty</p>
            </div>
          ) : (
            items.map(item => (
              <div key={item.cartItemId} className="flex flex-col gap-2 p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-100 dark:border-slate-700">
                <div className="flex justify-between items-start">
                  <div>
                    <div className="font-semibold text-sm">{item.name}</div>
                    <div className="text-xs text-slate-500">${item.price.toFixed(2)}</div>
                  </div>
                  <div className="font-bold text-sm">${(item.price * item.quantity).toFixed(2)}</div>
                </div>
                <div className="flex justify-between items-center mt-2">
                  <div className="flex items-center gap-1 bg-white dark:bg-slate-900 border dark:border-slate-700 rounded-md">
                    <Button variant="ghost" size="icon" className="h-7 w-7 rounded-none" onClick={() => updateQuantity(item.cartItemId, item.quantity - 1)}>
                      <Minus className="h-3 w-3" />
                    </Button>
                    <span className="w-8 text-center text-sm font-medium">{item.quantity}</span>
                    <Button variant="ghost" size="icon" className="h-7 w-7 rounded-none" onClick={() => updateQuantity(item.cartItemId, item.quantity + 1)}>
                      <Plus className="h-3 w-3" />
                    </Button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Totals & Checkout */}
        <div className="p-4 bg-slate-50 dark:bg-slate-900 border-t dark:border-slate-800 shrink-0">
          <div className="space-y-1.5 mb-4 text-sm">
            <div className="flex justify-between text-slate-500">
              <span>Subtotal</span>
              <span>${subtotal().toFixed(2)}</span>
            </div>
            <div className="flex justify-between text-slate-500">
              <span>Tax (10%)</span>
              <span>${taxAmount().toFixed(2)}</span>
            </div>
            <div className="flex justify-between font-bold text-lg pt-2 border-t dark:border-slate-200 dark:border-slate-700 mt-2">
              <span>Total</span>
              <span>${total().toFixed(2)}</span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <Button 
              className="w-full h-14 text-md font-semibold bg-green-600 hover:bg-green-700 text-white shadow-sm"
              disabled={items.length === 0}
              onClick={() => setCheckoutMethod('CASH')}
            >
              <Banknote className="mr-2 h-5 w-5" />
              Cash
            </Button>
            <Button 
              className="w-full h-14 text-md font-semibold bg-blue-600 hover:bg-blue-700 text-white shadow-sm"
              disabled={items.length === 0}
              onClick={() => setCheckoutMethod('CARD')}
            >
              <CreditCard className="mr-2 h-5 w-5" />
              Card
            </Button>
          </div>
        </div>
      </div>

      <CheckoutModal 
        open={checkoutMethod !== null} 
        onOpenChange={(open) => !open && setCheckoutMethod(null)} 
        method={checkoutMethod || 'CASH'}
      />
    </>
  )
}
