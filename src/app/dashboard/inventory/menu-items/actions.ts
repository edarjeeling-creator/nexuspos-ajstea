'use server'

import { createClient } from '@/utils/supabase/server'
import { revalidatePath } from 'next/cache'

export async function getMenuItems() {
  const supabase = await createClient()
  
  const { data, error } = await supabase
    .from('menu_items')
    .select(`
      *,
      category:categories(name)
    `)
    .is('deleted_at', null)
    .order('name')
    
  if (error) {
    console.error('Error fetching menu items:', error)
    return []
  }
  
  return data
}

export async function createMenuItem(formData: FormData) {
  const supabase = await createClient()
  
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')
    
  const { data: profile } = await supabase.from('profiles').select('tenant_id').eq('id', user.id).single()
  if (!profile?.tenant_id) throw new Error('No tenant associated with user')

  const name = formData.get('name') as string
  const item_code = formData.get('item_code') as string || null
  const category_id = formData.get('category_id') as string || null
  const price = parseFloat(formData.get('price') as string || '0')
  const menu_type = formData.get('menu_type') as string || 'FOOD'
  
  const { error } = await supabase
    .from('menu_items')
    .insert({
      tenant_id: profile.tenant_id,
      name,
      item_code,
      category_id: category_id === 'null' ? null : category_id,
      price,
      menu_type,
      is_available: true
    })
    
  if (error) {
    console.error('Error creating menu item:', error)
    return { error: error.message }
  }
  
  revalidatePath('/dashboard/inventory/menu-items')
  return { success: true }
}

export async function deleteMenuItem(id: string) {
  const supabase = await createClient()
  
  const { error } = await supabase
    .from('menu_items')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', id)
    
  if (error) {
    console.error('Error deleting menu item:', error)
    return { error: error.message }
  }
  
  revalidatePath('/dashboard/inventory/menu-items')
  return { success: true }
}
