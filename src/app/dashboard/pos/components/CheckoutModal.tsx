'use client'

import { useState } from 'react'
import { usePosStore } from '@/store/usePosStore'
import { posDb } from '@/lib/db/pos-db'
import { useTenantStore } from '@/store/useTenantStore'
import { useShiftStore } from '@/store/useShiftStore'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { CheckCircle2, Loader2, Printer } from 'lucide-react'

interface CheckoutModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  method: 'CASH' | 'CARD';
}

export function CheckoutModal({ open, onOpenChange, method }: CheckoutModalProps) {
  const { items, total, orderId, clearCart } = usePosStore()
  const { tenantId, outletId } = useTenantStore()
  const { shiftId, cashRegisterId } = useShiftStore()
  const [cashTendered, setCashTendered] = useState<string>('')
  const [processing, setProcessing] = useState(false)
  const [success, setSuccess] = useState(false)
  const [receiptNumber, setReceiptNumber] = useState('')

  const orderTotal = total()
  const changeDue = parseFloat(cashTendered || '0') - orderTotal

  const handleCheckout = async () => {
    if (method === 'CASH' && changeDue < 0) return;
    
    setProcessing(true)
    
    // Process Event Append-Only logic
    const now = new Date().toISOString()
    const payload = {
      items,
      total: orderTotal,
      method,
      amount_tendered: method === 'CASH' ? parseFloat(cashTendered) : orderTotal,
      change_due: method === 'CASH' ? changeDue : 0,
    }

    // Hybrid Receipt ID: OUTLET-REG-DATE-SEQ
    // Mocking sequence for MVP
    const sequence = Math.floor(Math.random() * 1000).toString().padStart(4, '0')
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '')
    const hybridReceiptNumber = `OUT-REG1-${dateStr}-${sequence}`
    setReceiptNumber(hybridReceiptNumber)

    try {
      // 1. ORDER_CREATED event
      await posDb.outbox_events.add({
        id: crypto.randomUUID(),
        tenant_id: tenantId || 'UNKNOWN',
        outlet_id: outletId || 'UNKNOWN',
        order_id: orderId,
        event_type: 'ORDER_CREATED',
        payload: payload,
        device_identifier: cashRegisterId || 'REG-1',
        shift_id: shiftId,
        created_at: now,
        sync_status: 'PENDING',
        sync_attempts: 0
      } as any)

      // Simulate hardware processing delay (e.g. card terminal, drawer kick)
      setTimeout(() => {
        setProcessing(false)
        setSuccess(true)
      }, 800)
    } catch (e) {
      console.error(e)
      setProcessing(false)
    }
  }

  const handleClose = () => {
    if (success) {
      clearCart()
      setCashTendered('')
    }
    setSuccess(false)
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{success ? 'Payment Successful' : `Checkout - ${method}`}</DialogTitle>
          <DialogDescription>
            {success ? 'Order has been recorded locally and queued for sync.' : `Complete the transaction for $${orderTotal.toFixed(2)}`}
          </DialogDescription>
        </DialogHeader>

        {!success ? (
          <div className="flex flex-col gap-4 py-4">
            <div className="flex justify-between items-center bg-slate-100 dark:bg-slate-800 p-4 rounded-lg">
              <span className="font-semibold text-lg">Total Due</span>
              <span className="font-bold text-2xl text-blue-600 dark:text-blue-400">${orderTotal.toFixed(2)}</span>
            </div>

            {method === 'CASH' && (
              <>
                <div className="space-y-2">
                  <label className="text-sm font-medium">Cash Tendered</label>
                  <Input 
                    type="number" 
                    placeholder="0.00" 
                    value={cashTendered}
                    onChange={(e) => setCashTendered(e.target.value)}
                    className="text-2xl h-14 font-bold"
                    autoFocus
                  />
                </div>
                {parseFloat(cashTendered) > 0 && (
                  <div className="flex justify-between items-center text-lg mt-2 p-2">
                    <span className="text-slate-500 font-medium">Change Due</span>
                    <span className={`font-bold text-2xl ${changeDue >= 0 ? 'text-green-600' : 'text-red-500'}`}>
                      ${changeDue >= 0 ? changeDue.toFixed(2) : 'Insufficient'}
                    </span>
                  </div>
                )}
              </>
            )}
            
            {method === 'CARD' && (
               <div className="py-8 text-center text-slate-500">
                  Ready to swipe or tap terminal...
               </div>
            )}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-6 gap-4">
            <div className="h-20 w-20 bg-green-100 dark:bg-green-900/30 rounded-full flex items-center justify-center text-green-600 dark:text-green-500">
              <CheckCircle2 className="h-10 w-10" />
            </div>
            <div className="text-center w-full bg-slate-50 dark:bg-slate-800/50 p-4 rounded-lg border border-slate-100 dark:border-slate-700">
              <p className="text-sm text-slate-500 mb-1 font-medium">Receipt Number</p>
              <p className="font-mono font-bold text-xl">{receiptNumber}</p>
            </div>
          </div>
        )}

        <DialogFooter className="gap-2 sm:gap-0">
          {!success ? (
            <Button 
              className="w-full h-12 text-md font-bold" 
              onClick={handleCheckout}
              disabled={processing || (method === 'CASH' && changeDue < 0)}
            >
              {processing ? (
                <><Loader2 className="mr-2 h-5 w-5 animate-spin" /> Processing...</>
              ) : (
                `Complete Transaction`
              )}
            </Button>
          ) : (
            <>
              <Button variant="outline" className="w-full h-12" onClick={() => { /* Print logic */ }}>
                <Printer className="mr-2 h-4 w-4" /> Print Receipt
              </Button>
              <Button className="w-full h-12" onClick={handleClose}>
                New Order
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
