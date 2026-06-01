import { useState, useEffect } from 'react'
import { createClient } from '@/utils/supabase/client'

import { useTenant } from '@/providers/TenantProvider'

export type KdsItem = {
  id: string
  order_id: string
  quantity: number
  status: string
  notes: string | null
  menu_items: { name: string }
}

export type KdsOrder = {
  id: string
  order_number: string
  order_type: string
  table_number: string | null
  status: string
  notes: string | null
  created_at: string
  order_items: KdsItem[]
}

export function useKdsOrders(stationType: string) {
  const { currentTenant, currentOutlet } = useTenant()
  const [orders, setOrders] = useState<KdsOrder[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const supabase = createClient()

  useEffect(() => {
    if (!currentTenant || !currentOutlet) return

    const fetchOrders = async () => {
      try {
        setLoading(true)
        const { data, error: err } = await supabase
          .from('orders')
          .select(`
            id, order_number, order_type, table_number, status, notes, created_at,
            order_items!inner(id, order_id, quantity, status, notes, menu_items(name), preparation_station)
          `)
          .eq('tenant_id', currentTenant.id)
          .eq('outlet_id', currentOutlet.id)
          .eq('order_items.preparation_station', stationType)
          .neq('status', 'COMPLETED')
          .neq('status', 'CANCELLED')
          .order('created_at', { ascending: true })
          
        if (err) throw err
        setOrders(data as unknown as KdsOrder[])
      } catch (err: any) {
        setError(err)
      } finally {
        setLoading(false)
      }
    }

    fetchOrders()

    // Setup Realtime Subscription
    // We listen to changes on order_items because individual items transition states
    const subscription = supabase
      .channel(`kds_${stationType}_${currentOutlet.id}`)
      .on('postgres_changes', { 
        event: '*', 
        schema: 'public', 
        table: 'order_items',
        filter: `tenant_id=eq.${currentTenant.id}`
      }, (payload) => {
        // Refetch to ensure we get the full joined payload including menu item names and order details.
        // In a highly optimized prod environment, we would manually mutate the state.
        fetchOrders()
        // Play sound if it's a new insert
        if (payload.eventType === 'INSERT') {
          playNewOrderSound()
        }
      })
      .on('postgres_changes', { 
        event: '*', 
        schema: 'public', 
        table: 'orders',
        filter: `tenant_id=eq.${currentTenant.id}`
      }, (payload) => {
        fetchOrders()
      })
      .subscribe()

    return () => {
      subscription.unsubscribe()
    }
  }, [currentTenant, currentOutlet, stationType])

  const playNewOrderSound = () => {
    try {
      // Use a simple browser beep since we don't have an asset
      const ctx = new (window.AudioContext || (window as any).webkitAudioContext)()
      const osc = ctx.createOscillator()
      osc.type = 'sine'
      osc.frequency.setValueAtTime(880, ctx.currentTime) // A5
      osc.connect(ctx.destination)
      osc.start()
      osc.stop(ctx.currentTime + 0.1)
      
      setTimeout(() => {
        const osc2 = ctx.createOscillator()
        osc2.type = 'sine'
        osc2.frequency.setValueAtTime(1108.73, ctx.currentTime) // C#6
        osc2.connect(ctx.destination)
        osc2.start()
        osc2.stop(ctx.currentTime + 0.2)
      }, 150)
    } catch (e) {
      console.warn("AudioContext not supported")
    }
  }

  const updateItemStatus = async (itemId: string, newStatus: string) => {
    if (!currentTenant) return
    
    // Optimistic update
    setOrders(prev => prev.map(order => ({
      ...order,
      order_items: order.order_items.map(item => 
        item.id === itemId ? { ...item, status: newStatus } : item
      )
    })))

    const { error } = await supabase
      .from('order_items')
      .update({ status: newStatus })
      .eq('id', itemId)
      .eq('tenant_id', currentTenant.id)

    if (error) {
      console.error('Error updating item status:', error)
      // We rely on realtime to sync back if there was an error, or we could refetch
    }
  }

  const bumpOrder = async (orderId: string) => {
    if (!currentTenant) return
    
    // Bump order will mark all items in this station for this order as SERVED
    // And possibly mark the order as COMPLETED if all its items are SERVED
    
    // Optimistic update
    setOrders(prev => prev.filter(o => o.id !== orderId))

    // Mark items as served
    const orderToBump = orders.find(o => o.id === orderId)
    if (!orderToBump) return
    
    const itemIds = orderToBump.order_items.map(i => i.id)
    
    await supabase
      .from('order_items')
      .update({ status: 'SERVED' })
      .in('id', itemIds)
      .eq('tenant_id', currentTenant.id)
      
    // In a real app, a trigger or backend function would check if ALL items for the order are served, 
    // and if so, update the order status. For now, we just update the items, 
    // and our UI filters them out on refetch.
  }

  return { orders, loading, error, updateItemStatus, bumpOrder }
}
