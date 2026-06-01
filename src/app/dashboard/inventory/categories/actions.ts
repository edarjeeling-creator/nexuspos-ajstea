'use server'

import { createClient } from '@/utils/supabase/server'
import { revalidatePath } from 'next/cache'

export async function getCategories() {
  const supabase = await createClient()
  
  const { data, error } = await supabase
    .from('categories')
    .select('*')
    .is('deleted_at', null)
    .order('name')
    
  if (error) {
    console.error('Error fetching categories:', error)
    return []
  }
  
  return data
}

export async function createCategory(formData: FormData) {
  const supabase = await createClient()
  
  // We need to fetch tenant_id from current user profile. Wait, RLS inserts might fail if tenant_id is NOT provided 
  // explicitly, unless there's a trigger to set it. 
  // Let's fetch tenant_id first.
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')
    
  const { data: profile } = await supabase
    .from('profiles')
    .select('tenant_id')
    .eq('id', user.id)
    .single()
    
  if (!profile?.tenant_id) throw new Error('No tenant associated with user')

  const name = formData.get('name') as string
  const status = formData.get('status') as string || 'ACTIVE'
  
  const { error } = await supabase
    .from('categories')
    .insert({
      tenant_id: profile.tenant_id,
      name,
      status
    })
    
  if (error) {
    console.error('Error creating category:', error)
    return { error: error.message }
  }
  
  revalidatePath('/dashboard/inventory/categories')
  return { success: true }
}

export async function deleteCategory(id: string) {
  const supabase = await createClient()
  
  // Soft delete
  const { error } = await supabase
    .from('categories')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', id)
    
  if (error) {
    console.error('Error deleting category:', error)
    return { error: error.message }
  }
  
  revalidatePath('/dashboard/inventory/categories')
  return { success: true }
}
