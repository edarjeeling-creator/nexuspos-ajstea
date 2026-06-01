'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle, CardFooter } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Clock, AlertTriangle, CheckCircle, ChefHat, ArrowRight } from 'lucide-react'
import { useParams } from 'next/navigation'
import Link from 'next/link'
import { useKdsOrders } from '@/hooks/useKdsOrders'
import { RouteGuard } from '@/components/auth/route-guard'
import { Skeleton } from '@/components/ui/skeleton'

export default function KDSStationScreen() {
  const params = useParams()
  const stationId = (params.stationId as string).toUpperCase() // BAR, KITCHEN, BAKERY, DESSERT
  const { orders, loading, error, updateItemStatus, bumpOrder } = useKdsOrders(stationId)

  const getTimerColor = (createdAt: string) => {
    const minutes = Math.floor((Date.now() - new Date(createdAt).getTime()) / 60000)
    if (minutes < 5) return 'bg-emerald-500 text-white border-emerald-600'
    if (minutes < 10) return 'bg-amber-400 text-slate-900 border-amber-500'
    return 'bg-red-500 text-white border-red-600 shadow-[0_0_15px_rgba(239,68,68,0.3)] animate-pulse'
  }

  const getTimerMinutes = (createdAt: string) => {
    return Math.floor((Date.now() - new Date(createdAt).getTime()) / 60000)
  }

  // Force re-render every minute to update timers
  const [, setTick] = useState(0)
  useEffect(() => {
    const timer = setInterval(() => setTick(t => t + 1), 60000)
    return () => clearInterval(timer)
  }, [])

  const nextItemStatus = (currentStatus: string) => {
    if (currentStatus === 'PENDING' || currentStatus === 'NEW') return 'PREPARING'
    if (currentStatus === 'PREPARING') return 'READY'
    return currentStatus
  }

  return (
    <RouteGuard module="pos">
      <div className="min-h-screen bg-slate-950 text-slate-100 p-4 font-sans">
        {/* KDS HEADER */}
        <header className="flex items-center justify-between pb-4 border-b border-slate-800 mb-6">
          <div className="flex items-center gap-4">
            <Button variant="outline" size="sm" asChild className="text-slate-900 dark:text-white border-slate-700 bg-slate-900">
              <Link href="/dashboard/kds">Back</Link>
            </Button>
            <h1 className="text-2xl font-bold flex items-center gap-2">
              <ChefHat className="text-indigo-400" /> {stationId} KDS
            </h1>
          </div>
          <div className="flex items-center gap-4 text-sm font-mono">
            <div className="flex items-center gap-2 px-3 py-1 rounded bg-slate-800 border border-slate-700">
              <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              Realtime Active
            </div>
            <div className="text-slate-400 text-lg font-bold">
              {new Date().toLocaleTimeString()}
            </div>
          </div>
        </header>

        {error && (
          <div className="mb-6 bg-red-900/50 border border-red-500 text-red-200 p-4 rounded-lg flex items-center gap-3">
            <AlertTriangle className="h-6 w-6 text-red-400" />
            <div>
              <h3 className="font-bold text-red-100">Connection Error</h3>
              <p className="text-sm">{error.message}</p>
            </div>
          </div>
        )}

        {/* KANBAN BOARD */}
        {loading && orders.length === 0 ? (
           <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
             {[1,2,3].map(i => <Skeleton key={i} className="h-64 w-full bg-slate-800" />)}
           </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 items-start">
            {orders.length === 0 && (
              <div className="col-span-full text-center py-20 text-slate-500">
                <ChefHat className="w-16 h-16 mx-auto mb-4 opacity-20" />
                <h2 className="text-2xl font-bold">No active orders for {stationId}</h2>
                <p>Waiting for new tickets...</p>
              </div>
            )}
            
            {orders.map(order => {
              // Extract last 3 characters for token, or fallback
              const tokenNumber = order.order_number?.slice(-3) || '000'
              // Check if all items in this ticket are READY
              const allReady = order.order_items.every(i => i.status === 'READY' || i.status === 'SERVED')
              
              return (
                <Card key={order.id} className={`border-2 bg-slate-900 text-slate-100 border-slate-700 flex flex-col`}>
                  <CardHeader className={`p-3 border-b ${getTimerColor(order.created_at)}`}>
                    <div className="flex justify-between items-center">
                      <div className="flex gap-2 items-baseline">
                        <CardTitle className="text-2xl font-black">#{tokenNumber}</CardTitle>
                        <span className="text-sm font-semibold opacity-90">({order.order_number})</span>
                      </div>
                      <span className="text-xs font-bold px-2 py-1 bg-black/30 rounded uppercase tracking-wider">
                        {order.order_type.replace('_', ' ')}
                      </span>
                    </div>
                    <div className="flex justify-between items-center text-xs opacity-90 mt-1 font-semibold">
                      <span>{order.table_number ? `Table ${order.table_number}` : 'No Table'}</span>
                      <span className="flex items-center gap-1 font-mono text-base">
                        <Clock className="w-4 h-4" />
                        {getTimerMinutes(order.created_at)}m
                      </span>
                    </div>
                  </CardHeader>
                  
                  {order.notes && (
                    <div className="bg-yellow-500/20 border-b border-yellow-500/50 p-2 text-yellow-200 text-sm font-bold flex items-start gap-2">
                      <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
                      {order.notes}
                    </div>
                  )}
                  
                  <CardContent className="p-0 flex-1">
                    <ul className="divide-y divide-slate-800">
                      {order.order_items.map((item) => (
                        <li 
                          key={item.id} 
                          className={`p-4 hover:bg-slate-800/50 transition-colors cursor-pointer active:bg-slate-700
                            ${item.status === 'READY' ? 'opacity-50 line-through' : ''}
                            ${item.status === 'PREPARING' ? 'bg-indigo-900/20' : ''}
                          `}
                          onClick={() => {
                            const next = nextItemStatus(item.status);
                            if (next !== item.status) updateItemStatus(item.id, next);
                          }}
                        >
                          <div className="flex gap-4">
                            <div className="font-mono text-2xl font-black text-indigo-400">{item.quantity}x</div>
                            <div className="flex-1">
                              <div className="text-xl font-bold leading-tight">{item.menu_items?.name || 'Unknown Item'}</div>
                              {item.notes && (
                                <div className="text-sm text-amber-400 mt-2 font-medium bg-amber-400/10 p-1.5 rounded inline-block">
                                  {item.notes}
                                </div>
                              )}
                            </div>
                          </div>
                        </li>
                      ))}
                    </ul>
                  </CardContent>
                  
                  <CardFooter className="p-3 border-t border-slate-800 bg-slate-950 mt-auto">
                    <Button 
                      className={`w-full h-16 text-xl font-bold transition-all shadow-lg
                        ${allReady 
                          ? 'bg-emerald-600 hover:bg-emerald-700 text-white animate-pulse' 
                          : 'bg-slate-800 hover:bg-slate-700 text-slate-300'}`}
                      onClick={() => bumpOrder(order.id)}
                    >
                      {allReady ? (
                        <>Bump Ticket <ArrowRight className="ml-2 w-6 h-6" /></>
                      ) : (
                        'Bump Ticket (Force)'
                      )}
                    </Button>
                  </CardFooter>
                </Card>
              )
            })}
          </div>
        )}
      </div>
    </RouteGuard>
  )
}
