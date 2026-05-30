'use client'

import { ProductGrid } from './components/ProductGrid'
import { Cart } from './components/Cart'
import { SyncStatusIndicator } from './components/SyncStatusIndicator'
import { RouteGuard } from '@/components/auth/route-guard'
import { Suspense, useState, useEffect } from 'react'
import { useShiftStore } from '@/store/useShiftStore'
import { Button } from '@/components/ui/button'
import { Lock, Unlock } from 'lucide-react'
import { OpenTillModal } from './components/OpenTillModal'
import { CloseTillModal } from './components/CloseTillModal'

export default function POSPage() {
  const { isOpen, cashRegisterName } = useShiftStore()
  const [openModal, setOpenModal] = useState<'OPEN' | 'CLOSE' | null>(null)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  if (!mounted) return null;

  return (
    <RouteGuard module="pos">
      <div className="flex flex-col h-[calc(100vh-80px)] -m-4 sm:-m-6 lg:-m-8 bg-slate-100 dark:bg-slate-950 relative">
        
        {/* POS Specific Header */}
        <div className="h-12 bg-white dark:bg-slate-900 border-b dark:border-slate-800 flex items-center justify-between px-4 shrink-0 z-20 relative">
          <div className="flex items-center gap-4">
            <span className="font-bold tracking-tight text-slate-800 dark:text-slate-200">
              {cashRegisterName || 'Terminal 1'}
            </span>
            <div className="h-4 w-[1px] bg-slate-200 dark:bg-slate-700"></div>
            <span className="text-sm font-medium text-slate-500 flex items-center gap-2">
              {isOpen ? (
                <><span className="h-2 w-2 rounded-full bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.6)]"></span> Shift Open</>
              ) : (
                <><span className="h-2 w-2 rounded-full bg-slate-300 dark:bg-slate-700"></span> Shift Closed</>
              )}
            </span>
          </div>
          <div className="flex items-center gap-3">
            {isOpen ? (
              <Button variant="outline" size="sm" onClick={() => setOpenModal('CLOSE')} className="h-8">
                <Lock className="mr-2 h-3.5 w-3.5 text-slate-500" /> Close Till
              </Button>
            ) : (
              <Button variant="default" size="sm" onClick={() => setOpenModal('OPEN')} className="h-8 bg-indigo-600 hover:bg-indigo-700">
                <Unlock className="mr-2 h-3.5 w-3.5" /> Open Till
              </Button>
            )}
            <Suspense fallback={null}>
              <SyncStatusIndicator />
            </Suspense>
          </div>
        </div>

        {/* POS Body (Grid + Cart) */}
        <div className="flex flex-1 overflow-hidden flex-col lg:flex-row relative">
          
          {/* Lock Overlay */}
          {!isOpen && (
            <div className="absolute inset-0 z-10 bg-slate-100/60 dark:bg-slate-950/60 backdrop-blur-sm flex flex-col items-center justify-center">
              <div className="bg-white dark:bg-slate-900 p-8 rounded-2xl shadow-xl flex flex-col items-center max-w-md text-center border border-slate-200 dark:border-slate-800 animate-in fade-in zoom-in duration-300">
                <div className="h-20 w-20 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center mb-6">
                  <Lock className="h-10 w-10 text-slate-400" />
                </div>
                <h2 className="text-2xl font-bold mb-2">Terminal Locked</h2>
                <p className="text-slate-500 dark:text-slate-400 mb-8 leading-relaxed">
                  You must open a shift and declare the starting float before processing transactions on this register.
                </p>
                <Button size="lg" className="w-full text-md font-semibold bg-indigo-600 hover:bg-indigo-700 h-14" onClick={() => setOpenModal('OPEN')}>
                  <Unlock className="mr-2 h-5 w-5" /> Open Till Now
                </Button>
              </div>
            </div>
          )}

          <div className="flex-1 p-4 lg:p-6 overflow-hidden bg-slate-50/50 dark:bg-slate-950/50">
            <ProductGrid />
          </div>
          <div className="w-full lg:w-[400px] shrink-0 border-t lg:border-t-0 border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 z-0 h-full">
            <Cart />
          </div>
        </div>
      </div>

      <OpenTillModal open={openModal === 'OPEN'} onOpenChange={(val) => !val && setOpenModal(null)} />
      <CloseTillModal open={openModal === 'CLOSE'} onOpenChange={(val) => !val && setOpenModal(null)} />

    </RouteGuard>
  )
}
