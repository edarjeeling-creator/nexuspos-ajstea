'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle, CardFooter } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Clock, AlertTriangle, CheckCircle, ChefHat } from 'lucide-react'
import { useParams } from 'next/navigation'
import Link from 'next/link'

// Mock Realtime Data Structure
const INITIAL_TICKETS = [
  { 
    id: 't1', 
    order_number: '1042', 
    type: 'DINE_IN', 
    priority: 'HIGH', 
    status: 'NEW', 
    created_at: new Date(Date.now() - 1000 * 60 * 2).toISOString(),
    items: [
      { id: 'i1', name: 'Classic Burger', qty: 2, modifiers: { no_onion: true } },
      { id: 'i2', name: 'Truffle Fries', qty: 1, modifiers: null }
    ]
  },
  { 
    id: 't2', 
    order_number: '1043', 
    type: 'TAKEAWAY', 
    priority: 'NORMAL', 
    status: 'PREPARING', 
    created_at: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
    items: [
      { id: 'i3', name: 'Spicy Chicken Sandwich', qty: 1, modifiers: { extra_spicy: true } }
    ]
  }
]

export default function KDSStationScreen() {
  const params = useParams()
  const stationId = params.stationId as string
  const [tickets, setTickets] = useState(INITIAL_TICKETS)
  const [recoveryAlert, setRecoveryAlert] = useState(false)

  // Mocking Supabase Realtime & Recovery logic
  useEffect(() => {
    // If we receive a sudden burst of old tickets (offline sync burst), show alert
    const burst = tickets.filter(t => t.status === 'NEW' && (Date.now() - new Date(t.created_at).getTime() > 1000 * 60 * 30))
    if (burst.length > 0) {
      setRecoveryAlert(true)
    }
  }, [tickets])

  const bumpTicket = (id: string, currentStatus: string) => {
    setTickets(prev => prev.map(t => {
      if (t.id === id) {
        if (currentStatus === 'NEW') return { ...t, status: 'PREPARING' }
        if (currentStatus === 'PREPARING') return { ...t, status: 'READY' }
      }
      return t
    }).filter(t => t.status !== 'READY')) // Remove if ready to keep screen clear
  }

  const getPriorityColor = (priority: string) => {
    if (priority === 'URGENT' || priority === 'VIP') return 'bg-red-500 text-white border-red-600'
    if (priority === 'HIGH') return 'bg-amber-500 text-white border-amber-600'
    return 'bg-slate-200 dark:bg-slate-800 text-slate-800 dark:text-slate-200 border-slate-300 dark:border-slate-700'
  }

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 p-4 font-sans">
      {/* KDS HEADER */}
      <header className="flex items-center justify-between pb-4 border-b border-slate-800 mb-6">
        <div className="flex items-center gap-4">
          <Button variant="outline" size="sm" asChild className="text-slate-900 dark:text-white">
             <Link href="/dashboard/kds">Back</Link>
          </Button>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <ChefHat className="text-indigo-400" /> Grill Station KDS
          </h1>
        </div>
        <div className="flex items-center gap-4 text-sm font-mono">
           <div className="flex items-center gap-2 px-3 py-1 rounded bg-slate-800 border border-slate-700">
             <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
             Realtime Active
           </div>
           <div className="text-slate-400 text-lg font-bold">
             {new Date().toLocaleTimeString()}
           </div>
        </div>
      </header>

      {/* RECOVERY ALERT */}
      {recoveryAlert && (
        <div className="mb-6 bg-red-900/50 border border-red-500 text-red-200 p-4 rounded-lg flex items-center gap-3 animate-in fade-in slide-in-from-top-4">
          <AlertTriangle className="h-6 w-6 text-red-400" />
          <div>
            <h3 className="font-bold text-red-100">Offline Recovery Sync Detected</h3>
            <p className="text-sm">The POS just pushed backlogged tickets to the cloud. Some tickets may be older than they appear.</p>
          </div>
          <Button variant="outline" size="sm" className="ml-auto text-red-900" onClick={() => setRecoveryAlert(false)}>Acknowledge</Button>
        </div>
      )}

      {/* KANBAN BOARD */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 items-start">
        {tickets.map(ticket => {
          const isLate = (Date.now() - new Date(ticket.created_at).getTime()) > 1000 * 60 * 15 // 15 mins
          
          return (
            <Card key={ticket.id} className={`border-2 bg-slate-800 text-slate-100 ${isLate ? 'border-red-500 shadow-[0_0_15px_rgba(239,68,68,0.2)]' : 'border-slate-700'}`}>
              <CardHeader className={`p-3 border-b ${getPriorityColor(ticket.priority)}`}>
                <div className="flex justify-between items-center">
                  <CardTitle className="text-xl font-bold">#{ticket.order_number}</CardTitle>
                  <span className="text-xs font-bold px-2 py-1 bg-black/20 rounded uppercase">
                    {ticket.type.replace('_', ' ')}
                  </span>
                </div>
                <div className="flex justify-between items-center text-xs opacity-90 mt-1">
                  <span>{ticket.status}</span>
                  <span className="flex items-center gap-1 font-mono">
                    <Clock className="w-3 h-3" />
                    {Math.floor((Date.now() - new Date(ticket.created_at).getTime()) / 60000)}m
                  </span>
                </div>
              </CardHeader>
              
              <CardContent className="p-0">
                <ul className="divide-y divide-slate-700">
                  {ticket.items.map((item, idx) => (
                    <li key={idx} className="p-3 hover:bg-slate-700/50 transition-colors">
                      <div className="flex gap-3">
                        <div className="font-mono text-lg font-bold text-indigo-400">{item.qty}x</div>
                        <div className="flex-1">
                          <div className="text-lg font-semibold">{item.name}</div>
                          {item.modifiers && (
                            <div className="text-sm text-amber-400 mt-1 font-medium">
                              {Object.keys(item.modifiers).map(m => `**${m.replace('_', ' ')}**`).join(', ')}
                            </div>
                          )}
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              </CardContent>
              
              <CardFooter className="p-3 border-t border-slate-700">
                <Button 
                  className={`w-full h-14 text-lg font-bold ${ticket.status === 'NEW' ? 'bg-indigo-600 hover:bg-indigo-700' : 'bg-green-600 hover:bg-green-700'}`}
                  onClick={() => bumpTicket(ticket.id, ticket.status)}
                >
                  {ticket.status === 'NEW' ? 'Start Preparing' : <><CheckCircle className="mr-2" /> Mark Ready</>}
                </Button>
              </CardFooter>
            </Card>
          )
        })}
      </div>
    </div>
  )
}
