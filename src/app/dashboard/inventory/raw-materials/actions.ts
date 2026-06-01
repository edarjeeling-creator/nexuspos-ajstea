'use server'

import { createClient } from '@/utils/supabase/server'
import { revalidatePath } from 'next/cache'

export async function getRawMaterials() {
  const supabase = await createClient()
  
  const { data, error } = await supabase
    .from('inventory_items')
    .select(`
      *,
      category:categories(name)
    `)
    .eq('item_type', 'RAW_MATERIAL')
    .is('deleted_at', null)
    .order('name')
    
  if (error) {
    console.error('Error fetching raw materials:', error)
    return []
  }
  
  return data
}

export async function getCategories() {
  const supabase = await createClient()
  const { data } = await supabase.from('categories').select('id, name').is('deleted_at', null).order('name')
  return data || []
}

export async function createRawMaterial(formData: FormData) {
  const supabase = await createClient()
  
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')
    
  const { data: profile } = await supabase.from('profiles').select('tenant_id').eq('id', user.id).single()
  if (!profile?.tenant_id) throw new Error('No tenant associated with user')

  const name = formData.get('name') as string
  const sku = formData.get('sku') as string
  const category_id = formData.get('category_id') as string || null
  const unit_of_measure = formData.get('unit_of_measure') as string
  const cost_price = parseFloat(formData.get('cost_price') as string || '0')
  const reorder_level = parseFloat(formData.get('reorder_level') as string || '0')
  
  const { error } = await supabase
    .from('inventory_items')
    .insert({
      tenant_id: profile.tenant_id,
      name,
      sku,
      category_id: category_id === 'null' ? null : category_id,
      unit_of_measure,
      cost_price,
      reorder_level,
      item_type: 'RAW_MATERIAL'
    })
    
  if (error) {
    console.error('Error creating raw material:', error)
    return { error: error.message }
  }
  
  revalidatePath('/dashboard/inventory/raw-materials')
  return { success: true }
}

export async function deleteRawMaterial(id: string) {
  const supabase = await createClient()
  
  const { error } = await supabase
    .from('inventory_items')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', id)
    
  if (error) {
    console.error('Error deleting raw material:', error)
    return { error: error.message }
  }
  
  revalidatePath('/dashboard/inventory/raw-materials')
  return { success: true }
}
