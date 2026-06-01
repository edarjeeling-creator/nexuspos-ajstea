'use server'

import { createClient } from '@/utils/supabase/server'
import { revalidatePath } from 'next/cache'

export async function getStockLevels() {
  const supabase = await createClient()
  
  // We fetch all items first
  const { data: items, error: itemsError } = await supabase
    .from('inventory_items')
    .select('id, name, sku, unit_of_measure, cost_price')
    .is('deleted_at', null)
    
  if (itemsError) {
    console.error('Error fetching inventory items:', itemsError)
    return []
  }

  // Then fetch all transactions to calculate stock
  const { data: transactions, error: txError } = await supabase
    .from('inventory_transactions')
    .select('inventory_item_id, quantity_change')
    .is('deleted_at', null)

  if (txError) {
    console.error('Error fetching inventory transactions:', txError)
    return []
  }

  // Aggregate stock
  const stockMap: Record<string, number> = {}
  transactions?.forEach(tx => {
    if (!stockMap[tx.inventory_item_id]) stockMap[tx.inventory_item_id] = 0
    stockMap[tx.inventory_item_id] += Number(tx.quantity_change)
  })

  // Combine
  return items?.map(item => ({
    ...item,
    current_stock: stockMap[item.id] || 0
  })) || []
}

export async function getWarehouses() {
  const supabase = await createClient()
  const { data } = await supabase.from('warehouses').select('id, name').order('name')
  return data || []
}

export async function addStockAdjustment(formData: FormData) {
  const supabase = await createClient()
  
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')
    
  const { data: profile } = await supabase.from('profiles').select('tenant_id, id').eq('id', user.id).single()
  if (!profile?.tenant_id) throw new Error('No tenant associated with user')

  const inventory_item_id = formData.get('inventory_item_id') as string
  const warehouse_id = formData.get('warehouse_id') as string || null
  const transaction_type = formData.get('transaction_type') as string
  let quantity_change = parseFloat(formData.get('quantity_change') as string || '0')
  const unit_cost = parseFloat(formData.get('unit_cost') as string || '0')
  const notes = formData.get('notes') as string
  
  // If transaction type is WASTE or SALE or TRANSFER_OUT, make quantity negative if user entered positive
  if (['WASTE', 'SALE', 'TRANSFER_OUT'].includes(transaction_type)) {
    if (quantity_change > 0) quantity_change = -quantity_change
  }

  const { error } = await supabase
    .from('inventory_transactions')
    .insert({
      tenant_id: profile.tenant_id,
      inventory_item_id,
      warehouse_id: warehouse_id === 'null' ? null : warehouse_id,
      transaction_type,
      quantity_change,
      unit_cost,
      reference_type: 'MANUAL_ADJUSTMENT',
      notes,
      created_by: profile.id
    })
    
  if (error) {
    console.error('Error adding stock adjustment:', error)
    return { error: error.message }
  }
  
  revalidatePath('/dashboard/inventory/stock')
  return { success: true }
}
