'use client'

import { useState } from 'react'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Loader2, ShieldAlert } from 'lucide-react'

export function ManagerOverrideModal({ open, onOpenChange, variance, onSuccess }: { open: boolean, onOpenChange: (open: boolean) => void, variance: number, onSuccess: () => void }) {
  const [pin, setPin] = useState('')
  const [reason, setReason] = useState('')
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState('')

  const handleAuthorize = async () => {
    if (pin.length < 4 || !reason) {
      setError('PIN and reason are required.')
      return;
    }
    
    setProcessing(true)
    setError('')
    
    // Simulate Local PIN check logic
    setTimeout(() => {
      if (pin === '1234') { // Mock secure PIN lookup
        onSuccess()
      } else {
        setError('Invalid PIN.')
        setProcessing(false)
      }
    }, 800)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md border-amber-200 dark:border-amber-900 bg-amber-50/30 dark:bg-amber-950/30 backdrop-blur-md">
        <DialogHeader>
          <div className="flex items-center gap-3 mb-2">
            <div className="h-10 w-10 bg-amber-100 dark:bg-amber-900/50 rounded-full flex items-center justify-center">
              <ShieldAlert className="h-5 w-5 text-amber-600 dark:text-amber-500" />
            </div>
            <DialogTitle>Manager Override Required</DialogTitle>
          </div>
          <DialogDescription>
            The till variance of <span className="font-bold text-red-600 dark:text-red-400">${Math.abs(variance).toFixed(2)}</span> exceeds the allowable threshold. A manager must authorize this closure.
          </DialogDescription>
        </DialogHeader>

        <div className="py-4 space-y-4">
           {error && <div className="p-3 bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400 text-sm font-medium rounded-lg border border-red-200 dark:border-red-900/50">{error}</div>}
           <div className="space-y-2">
              <label className="text-sm font-medium">Approval Reason</label>
              <Input 
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder="e.g., Shortchanged customer, counting error"
                className="h-12 bg-white dark:bg-slate-900"
              />
           </div>
           <div className="space-y-2">
              <label className="text-sm font-medium">Manager PIN</label>
              <Input 
                type="password" 
                maxLength={4}
                value={pin}
                onChange={(e) => setPin(e.target.value)}
                placeholder="****"
                className="h-14 text-center text-3xl tracking-[1em] font-mono bg-white dark:bg-slate-900"
              />
           </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} className="h-12 w-full sm:w-auto bg-white dark:bg-slate-900">Cancel</Button>
          <Button 
            onClick={handleAuthorize} 
            disabled={processing || pin.length < 4 || !reason}
            className="h-12 w-full sm:w-auto bg-amber-600 hover:bg-amber-700 text-white"
          >
            {processing && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Authorize Closure
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
