'use client'

import { useState, useMemo } from 'react'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useShiftStore } from '@/store/useShiftStore'
import { Loader2 } from 'lucide-react'
import { ManagerOverrideModal } from './ManagerOverrideModal'

export function CloseTillModal({ open, onOpenChange }: { open: boolean, onOpenChange: (open: boolean) => void }) {
  const { closeShift } = useShiftStore()
  
  const [denominations, setDenominations] = useState({
    hundreds: '', fifties: '', twenties: '', tens: '', fives: '', ones: '', coins: ''
  })
  
  const [processing, setProcessing] = useState(false)
  const [showOverride, setShowOverride] = useState(false)
  
  const expectedBalance = 550.00; // Mock expected balance
  const varianceThreshold = 5.00; // Mock threshold from config

  const actualBalance = useMemo(() => {
    return (
      (parseInt(denominations.hundreds || '0') * 100) +
      (parseInt(denominations.fifties || '0') * 50) +
      (parseInt(denominations.twenties || '0') * 20) +
      (parseInt(denominations.tens || '0') * 10) +
      (parseInt(denominations.fives || '0') * 5) +
      (parseInt(denominations.ones || '0') * 1) +
      parseFloat(denominations.coins || '0')
    )
  }, [denominations])

  const variance = actualBalance - expectedBalance
  const exceedsThreshold = Math.abs(variance) > varianceThreshold

  const handleCloseShift = async () => {
    if (exceedsThreshold) {
      setShowOverride(true)
      return;
    }
    finalizeClose()
  }

  const finalizeClose = () => {
    setProcessing(true)
    setTimeout(() => {
      closeShift()
      setProcessing(false)
      onOpenChange(false)
      setShowOverride(false)
    }, 1000)
  }

  const handleDenomChange = (key: string, val: string) => {
    setDenominations(prev => ({ ...prev, [key]: val }))
  }

  return (
    <>
      <Dialog open={open && !showOverride} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-lg max-h-[95vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Close Till</DialogTitle>
            <DialogDescription>
              Count the drawer and enter denominations to calculate the actual balance.
            </DialogDescription>
          </DialogHeader>

          <div className="grid grid-cols-2 gap-x-6 gap-y-4 py-4 border-b dark:border-slate-800">
             <div className="space-y-1">
               <label className="text-xs font-medium text-slate-500">$100 Bills</label>
               <Input type="number" placeholder="0" value={denominations.hundreds} onChange={e => handleDenomChange('hundreds', e.target.value)} className="bg-slate-50 dark:bg-slate-900" />
             </div>
             <div className="space-y-1">
               <label className="text-xs font-medium text-slate-500">$50 Bills</label>
               <Input type="number" placeholder="0" value={denominations.fifties} onChange={e => handleDenomChange('fifties', e.target.value)} className="bg-slate-50 dark:bg-slate-900" />
             </div>
             <div className="space-y-1">
               <label className="text-xs font-medium text-slate-500">$20 Bills</label>
               <Input type="number" placeholder="0" value={denominations.twenties} onChange={e => handleDenomChange('twenties', e.target.value)} className="bg-slate-50 dark:bg-slate-900" />
             </div>
             <div className="space-y-1">
               <label className="text-xs font-medium text-slate-500">$10 Bills</label>
               <Input type="number" placeholder="0" value={denominations.tens} onChange={e => handleDenomChange('tens', e.target.value)} className="bg-slate-50 dark:bg-slate-900" />
             </div>
             <div className="space-y-1">
               <label className="text-xs font-medium text-slate-500">$5 Bills</label>
               <Input type="number" placeholder="0" value={denominations.fives} onChange={e => handleDenomChange('fives', e.target.value)} className="bg-slate-50 dark:bg-slate-900" />
             </div>
             <div className="space-y-1">
               <label className="text-xs font-medium text-slate-500">$1 Bills</label>
               <Input type="number" placeholder="0" value={denominations.ones} onChange={e => handleDenomChange('ones', e.target.value)} className="bg-slate-50 dark:bg-slate-900" />
             </div>
             <div className="col-span-2 space-y-1 mt-2">
               <label className="text-xs font-medium text-slate-500">Total Coins Value ($)</label>
               <Input type="number" step="0.01" placeholder="0.00" value={denominations.coins} onChange={e => handleDenomChange('coins', e.target.value)} className="bg-slate-50 dark:bg-slate-900 text-lg font-bold" />
             </div>
          </div>

          <div className="py-2 space-y-3 bg-slate-50 dark:bg-slate-900 p-4 rounded-lg mt-2 border border-slate-100 dark:border-slate-800">
            <div className="flex justify-between items-center text-sm">
              <span className="text-slate-500 font-medium">Expected Balance</span>
              <span className="font-bold text-lg">${expectedBalance.toFixed(2)}</span>
            </div>
            <div className="flex justify-between items-center text-sm">
              <span className="text-slate-500 font-medium">Actual Count</span>
              <span className="font-bold text-lg">${actualBalance.toFixed(2)}</span>
            </div>
            <div className={`flex justify-between items-center pt-3 border-t dark:border-slate-700 font-bold text-xl ${variance === 0 ? 'text-green-600' : 'text-red-500'}`}>
              <span>Variance</span>
              <span>{variance > 0 ? '+' : ''}${variance.toFixed(2)}</span>
            </div>
          </div>

          <DialogFooter className="mt-4">
            <Button variant="outline" onClick={() => onOpenChange(false)} className="h-12 w-full sm:w-auto">Cancel</Button>
            <Button 
              onClick={handleCloseShift} 
              disabled={processing}
              className={`h-12 w-full sm:w-auto ${exceedsThreshold ? 'bg-amber-600 hover:bg-amber-700 text-white' : 'bg-slate-900 dark:bg-white text-white dark:text-slate-900'}`}
            >
              {processing && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {exceedsThreshold ? 'Requires Override' : 'Close Till'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ManagerOverrideModal 
        open={showOverride} 
        onOpenChange={(val) => {
           setShowOverride(val);
        }} 
        variance={variance}
        onSuccess={finalizeClose}
      />
    </>
  )
}
