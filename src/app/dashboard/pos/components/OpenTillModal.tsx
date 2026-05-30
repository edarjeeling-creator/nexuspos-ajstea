'use client'

import { useState } from 'react'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useShiftStore } from '@/store/useShiftStore'
import { createClient } from '@/utils/supabase/client'
import { useTenantStore } from '@/store/useTenantStore'
import { Loader2 } from 'lucide-react'

export function OpenTillModal({ open, onOpenChange }: { open: boolean, onOpenChange: (open: boolean) => void }) {
  const [startingFloat, setStartingFloat] = useState('')
  const [processing, setProcessing] = useState(false)
  const { openShift } = useShiftStore()
  const { tenantId, outletId } = useTenantStore()

  const handleOpenShift = async () => {
    if (!startingFloat || isNaN(parseFloat(startingFloat))) return;
    setProcessing(true);
    
    try {
      // Hardware/Register Binding
      const registerId = 'mock-reg-id' 
      const shiftId = crypto.randomUUID()
      
      // Instantly open shift locally
      openShift(registerId, 'Terminal 1', shiftId)

      setProcessing(false)
      onOpenChange(false)
      
    } catch (e) {
      console.error(e)
      setProcessing(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Open Till</DialogTitle>
          <DialogDescription>
            Enter the starting cash float currently in the drawer to begin the shift.
          </DialogDescription>
        </DialogHeader>

        <div className="py-6 space-y-4">
           <div className="space-y-2">
              <label className="text-sm font-medium">Starting Float Amount</label>
              <div className="relative">
                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 font-bold text-lg">$</span>
                <Input 
                  type="number" 
                  value={startingFloat}
                  onChange={(e) => setStartingFloat(e.target.value)}
                  className="pl-9 h-14 text-2xl font-bold bg-slate-50 dark:bg-slate-900 border-slate-200 dark:border-slate-800"
                  autoFocus
                  placeholder="0.00"
                />
              </div>
           </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} className="h-12 w-full sm:w-auto">Cancel</Button>
          <Button 
            onClick={handleOpenShift} 
            disabled={processing || !startingFloat || parseFloat(startingFloat) < 0}
            className="h-12 w-full sm:w-auto bg-indigo-600 hover:bg-indigo-700 text-white"
          >
            {processing && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Confirm Float
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
