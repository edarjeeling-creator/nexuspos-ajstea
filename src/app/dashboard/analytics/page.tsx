'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { DollarSign, ShoppingBag, TrendingUp, CreditCard, PieChart } from 'lucide-react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, ResponsiveContainer,
  LineChart, Line, PieChart as RePieChart, Pie, Cell, Legend
} from 'recharts'
import { createClient } from '@/utils/supabase/client'
import { useTenant } from '@/hooks/useTenant'

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884d8'];

export default function AnalyticsPage() {
  const supabase = createClient()
  const { outletId, isLoading: tenantLoading } = useTenant()

  const [isLoading, setIsLoading] = useState(true)
  const [metrics, setMetrics] = useState({
    todaySales: 0,
    weeklySales: 0,
    monthlySales: 0,
    totalOrders: 0,
    avgOrderValue: 0
  })
  
  const [hourlySales, setHourlySales] = useState<any[]>([])
  const [topSellers, setTopSellers] = useState<any[]>([])
  const [paymentBreakdown, setPaymentBreakdown] = useState<any[]>([])

  useEffect(() => {
    if (!outletId) return

    async function fetchAnalytics() {
      setIsLoading(true)
      
      // In a real app, these would ideally be aggregated via a materialized view or RPC function.
      // For this implementation, we simulate fetching aggregated data from the DB.
      
      const { data: ordersData } = await supabase
        .from('orders')
        .select('id, grand_total, created_at, payment_status, status, payments(payment_method)')
        .eq('tenant_id', (await supabase.from('outlets').select('tenant_id').eq('id', outletId).single()).data?.tenant_id)
        .eq('status', 'COMPLETED')
        
      if (ordersData) {
        // Compute Metrics
        const now = new Date()
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
        
        let todaySales = 0
        let weeklySales = 0
        let monthlySales = 0
        
        const oneWeekAgo = now.getTime() - 7 * 24 * 60 * 60 * 1000
        const oneMonthAgo = now.getTime() - 30 * 24 * 60 * 60 * 1000
        
        let totalSales = 0

        const hourMap: Record<string, number> = {}
        const paymentMap: Record<string, number> = {}

        ordersData.forEach((order) => {
          const orderTime = new Date(order.created_at).getTime()
          const total = Number(order.grand_total) || 0
          
          totalSales += total
          
          if (orderTime >= todayStart) todaySales += total
          if (orderTime >= oneWeekAgo) weeklySales += total
          if (orderTime >= oneMonthAgo) monthlySales += total

          // Hourly mapping (just using the hour string)
          const hour = new Date(order.created_at).getHours()
          const hourLabel = `${hour}:00`
          hourMap[hourLabel] = (hourMap[hourLabel] || 0) + total
          
          // Payment Breakdown
          const pMethod = (order.payments && order.payments[0]?.payment_method) || 'CASH'
          paymentMap[pMethod] = (paymentMap[pMethod] || 0) + total
        })

        const hourlyData = Object.keys(hourMap).map(k => ({ hour: k, sales: hourMap[k] }))
        hourlyData.sort((a, b) => parseInt(a.hour) - parseInt(b.hour))
        
        const paymentData = Object.keys(paymentMap).map(k => ({ name: k, value: paymentMap[k] }))

        setMetrics({
          todaySales,
          weeklySales,
          monthlySales,
          totalOrders: ordersData.length,
          avgOrderValue: ordersData.length > 0 ? totalSales / ordersData.length : 0
        })
        
        setHourlySales(hourlyData)
        setPaymentBreakdown(paymentData)
      }

      // Fetch top sellers (Simulation)
      // Usually would be grouped by menu_item_id in order_items
      const { data: orderItems } = await supabase
        .from('order_items')
        .select('menu_item_id, quantity, menu_items(name)')
        .eq('status', 'SERVED') // Assuming served items are completed
        .limit(100) // Just taking recent ones for the mock
        
      if (orderItems) {
        const itemMap: Record<string, {name: string, qty: number}> = {}
        orderItems.forEach((item: any) => {
          if (item.menu_items?.name) {
            const name = item.menu_items.name
            if (!itemMap[name]) itemMap[name] = { name, qty: 0 }
            itemMap[name].qty += item.quantity || 1
          }
        })
        
        const top = Object.values(itemMap).sort((a, b) => b.qty - a.qty).slice(0, 5)
        setTopSellers(top)
      }

      setIsLoading(false)
    }

    fetchAnalytics()
  }, [outletId, supabase])

  if (tenantLoading || isLoading) return <div className="p-8">Loading Analytics...</div>

  return (
    <div className="flex flex-col gap-6 p-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Analytics Dashboard</h1>
        <p className="text-slate-500 dark:text-slate-400 mt-1">
          Detailed breakdown of your store's performance.
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Today's Sales</CardTitle>
            <DollarSign className="h-4 w-4 text-emerald-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">${metrics.todaySales.toFixed(2)}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">This Week</CardTitle>
            <TrendingUp className="h-4 w-4 text-blue-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">${metrics.weeklySales.toFixed(2)}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Orders</CardTitle>
            <ShoppingBag className="h-4 w-4 text-indigo-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.totalOrders}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Order Value</CardTitle>
            <CreditCard className="h-4 w-4 text-purple-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">${metrics.avgOrderValue.toFixed(2)}</div>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-7">
        <Card className="col-span-4">
          <CardHeader>
            <CardTitle>Hourly Sales Trends (Today)</CardTitle>
            <CardDescription>Sales velocity broken down by hour</CardDescription>
          </CardHeader>
          <CardContent className="h-[300px]">
            {hourlySales.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={hourlySales} margin={{ top: 5, right: 20, bottom: 5, left: 0 }}>
                  <Line type="monotone" dataKey="sales" stroke="#8884d8" strokeWidth={2} />
                  <CartesianGrid stroke="#ccc" strokeDasharray="5 5" />
                  <XAxis dataKey="hour" />
                  <YAxis />
                  <RechartsTooltip />
                </LineChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex h-full items-center justify-center text-sm text-slate-500">No data available</div>
            )}
          </CardContent>
        </Card>

        <Card className="col-span-3">
          <CardHeader>
            <CardTitle>Payment Breakdown</CardTitle>
            <CardDescription>Revenue by payment method</CardDescription>
          </CardHeader>
          <CardContent className="h-[300px]">
            {paymentBreakdown.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <RePieChart>
                  <Pie
                    data={paymentBreakdown}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    outerRadius={100}
                    fill="#8884d8"
                    dataKey="value"
                    label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                  >
                    {paymentBreakdown.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <RechartsTooltip />
                </RePieChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex h-full items-center justify-center text-sm text-slate-500">No data available</div>
            )}
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-7">
        <Card className="col-span-4">
          <CardHeader>
            <CardTitle>Top Selling Items</CardTitle>
            <CardDescription>Most popular menu items</CardDescription>
          </CardHeader>
          <CardContent className="h-[300px]">
            {topSellers.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={topSellers} margin={{ top: 5, right: 20, bottom: 5, left: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <RechartsTooltip />
                  <Bar dataKey="qty" fill="#10b981" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex h-full items-center justify-center text-sm text-slate-500">No data available</div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
