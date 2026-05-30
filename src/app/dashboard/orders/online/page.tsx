'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardFooter } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { CheckCircle2, XCircle, Clock, Smartphone, MapPin, ChefHat } from 'lucide-react'
import { useState } from 'react'

const MOCK_ONLINE_ORDERS = [
  { id: '1', orderNum: 'WEB-4029', type: 'DELIVERY', status: 'PLACED', customer: 'Alice Johnson', amount: 45.50, time: '2 mins ago', items: 3 },
  { id: '2', orderNum: 'WEB-4030', type: 'TAKEAWAY', status: 'ACCEPTED', customer: 'Bob Smith', amount: 18.00, time: '8 mins ago', items: 1 },
  { id: '3', orderNum: 'QR-0992', type: 'DINE_IN_QR', status: 'IN_PREPARATION', customer: 'Table 14', amount: 82.25, time: '15 mins ago', items: 4 },
  { id: '4', orderNum: 'WEB-4031', type: 'PREORDER', status: 'PLACED', customer: 'Charlie Davis', amount: 120.00, time: '5 mins ago', items: 10, scheduledFor: 'Today 18:30' },
]

export default function OnlineOrderingQueue() {
  const [orders, setOrders] = useState(MOCK_ONLINE_ORDERS)

  const advanceOrder = (id: string, currentStatus: string) => {
    setOrders(prev => prev.map(o => {
      if (o.id === id) {
        if (currentStatus === 'PLACED') return { ...o, status: 'ACCEPTED' }
        if (currentStatus === 'ACCEPTED') return { ...o, status: 'IN_PREPARATION' }
        if (currentStatus === 'IN_PREPARATION') return { ...o, status: 'READY' }
        if (currentStatus === 'READY') return { ...o, status: 'COMPLETED' }
      }
      return o
    }).filter(o => o.status !== 'COMPLETED')) // Clear completed orders
  }

  const rejectOrder = (id: string) => {
    setOrders(prev => prev.filter(o => o.id !== id))
    // Trigger refund webhook
  }

  return (
    <RouteGuard module="pos">
      <div className="flex flex-col gap-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Online Order Queue</h1>
          <p className="text-slate-500 dark:text-slate-400 mt-1">
            Manage incoming Takeaway, Delivery, and QR Menu orders.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 items-start">
          {orders.map(order => (
            <Card key={order.id} className={`border-2 ${order.status === 'PLACED' ? 'border-indigo-500 shadow-md shadow-indigo-500/20' : 'border-slate-200 dark:border-slate-800'}`}>
              <CardHeader className="pb-3 border-b border-slate-100 dark:border-slate-800">
                <div className="flex justify-between items-start">
                  <div>
                    <CardTitle className="text-lg font-bold">{order.orderNum}</CardTitle>
                    <div className="text-sm font-medium mt-1 flex items-center gap-1 text-slate-500">
                      {order.type === 'DELIVERY' && <MapPin className="w-3 h-3" />}
                      {order.type === 'DINE_IN_QR' && <Smartphone className="w-3 h-3" />}
                      {order.type === 'TAKEAWAY' || order.type === 'PREORDER' ? <Clock className="w-3 h-3" /> : ''}
                      {order.type.replace('_', ' ')}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-bold text-lg">${order.amount.toFixed(2)}</div>
                    <div className="text-xs text-slate-500">{order.items} items</div>
                  </div>
                </div>
              </CardHeader>
              
              <CardContent className="py-4">
                <div className="flex items-center gap-2 mb-2">
                  <div className="w-8 h-8 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center font-bold text-slate-600 dark:text-slate-300">
                    {order.customer.charAt(0)}
                  </div>
                  <div className="font-medium">{order.customer}</div>
                </div>
                
                {order.scheduledFor && (
                  <div className="mt-3 p-2 bg-amber-50 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400 rounded text-xs font-bold flex items-center gap-2">
                    <Clock className="w-4 h-4" />
                    Scheduled For: {order.scheduledFor}
                  </div>
                )}
                
                <div className="mt-4 flex items-center justify-between text-xs font-bold">
                  <span className={`px-2 py-1 rounded 
                    ${order.status === 'PLACED' ? 'bg-indigo-100 text-indigo-700 dark:bg-indigo-900/30 dark:text-indigo-400' : ''}
                    ${order.status === 'ACCEPTED' ? 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' : ''}
                    ${order.status === 'IN_PREPARATION' ? 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400' : ''}
                    ${order.status === 'READY' ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : ''}
                  `}>
                    {order.status.replace('_', ' ')}
                  </span>
                  <span className="text-slate-500 flex items-center gap-1"><Clock className="w-3 h-3" /> {order.time}</span>
                </div>
              </CardContent>
              
              <CardFooter className="flex flex-col gap-2 pt-0 pb-4 px-4">
                {order.status === 'PLACED' && (
                  <div className="flex gap-2 w-full">
                    <Button className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white" onClick={() => advanceOrder(order.id, order.status)}>
                      Accept Order
                    </Button>
                    <Button variant="outline" className="text-red-500 border-red-200 hover:bg-red-50 dark:border-red-900 dark:hover:bg-red-950" onClick={() => rejectOrder(order.id)}>
                      Reject
                    </Button>
                  </div>
                )}
                
                {order.status === 'ACCEPTED' && (
                  <Button className="w-full bg-blue-600 hover:bg-blue-700 text-white" onClick={() => advanceOrder(order.id, order.status)}>
                    <ChefHat className="mr-2 h-4 w-4" /> Send to Kitchen
                  </Button>
                )}
                
                {order.status === 'IN_PREPARATION' && (
                  <Button className="w-full bg-orange-500 hover:bg-orange-600 text-white" onClick={() => advanceOrder(order.id, order.status)}>
                    Mark Ready
                  </Button>
                )}
                
                {order.status === 'READY' && (
                  <Button className="w-full bg-green-600 hover:bg-green-700 text-white" onClick={() => advanceOrder(order.id, order.status)}>
                    <CheckCircle2 className="mr-2 h-4 w-4" /> Handover to Customer/Driver
                  </Button>
                )}
              </CardFooter>
            </Card>
          ))}
          
          {orders.length === 0 && (
            <div className="col-span-full py-12 text-center text-slate-500 border-2 border-dashed border-slate-200 dark:border-slate-800 rounded-xl">
              No active online orders.
            </div>
          )}
        </div>
      </div>
    </RouteGuard>
  )
}
