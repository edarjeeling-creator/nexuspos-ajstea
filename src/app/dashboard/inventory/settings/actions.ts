'use server'

import { createClient } from '@/utils/supabase/server'
import { revalidatePath } from 'next/cache'

export async function seedInventoryData() {
  const supabase = await createClient()
  
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')
    
  const { data: profile } = await supabase.from('profiles').select('tenant_id').eq('id', user.id).single()
  if (!profile?.tenant_id) throw new Error('No tenant associated with user')

  const tenant_id = profile.tenant_id

  // 1. Categories
  const categories = [
    { tenant_id, name: 'Beverages', status: 'ACTIVE' },
    { tenant_id, name: 'Food', status: 'ACTIVE' },
    { tenant_id, name: 'Merchandise', status: 'ACTIVE' },
    { tenant_id, name: 'Raw Ingredients', status: 'ACTIVE' }
  ]
  const { data: insertedCategories, error: catError } = await supabase.from('categories').insert(categories).select()
  if (catError) return { error: catError.message }

  const bevCat = insertedCategories?.find(c => c.name === 'Beverages')?.id
  const foodCat = insertedCategories?.find(c => c.name === 'Food')?.id
  const rawCat = insertedCategories?.find(c => c.name === 'Raw Ingredients')?.id

  // 2. Raw Materials
  const rawMaterials = [
    { tenant_id, name: 'Darjeeling First Flush Tea Leaves', sku: 'TEA-DJ-1F', category_id: rawCat, unit_of_measure: 'kg', cost_price: 120.00, reorder_level: 5, item_type: 'RAW_MATERIAL' },
    { tenant_id, name: 'Assam CTC Tea', sku: 'TEA-AS-CTC', category_id: rawCat, unit_of_measure: 'kg', cost_price: 25.00, reorder_level: 20, item_type: 'RAW_MATERIAL' },
    { tenant_id, name: 'Whole Milk', sku: 'MILK-WHL', category_id: rawCat, unit_of_measure: 'L', cost_price: 1.20, reorder_level: 50, item_type: 'RAW_MATERIAL' },
    { tenant_id, name: 'Arabica Coffee Beans', sku: 'COF-ARA', category_id: rawCat, unit_of_measure: 'kg', cost_price: 35.00, reorder_level: 10, item_type: 'RAW_MATERIAL' },
    { tenant_id, name: 'All Purpose Flour', sku: 'FLR-AP', category_id: rawCat, unit_of_measure: 'kg', cost_price: 2.50, reorder_level: 50, item_type: 'RAW_MATERIAL' },
    { tenant_id, name: 'Sugar', sku: 'SGR-WHT', category_id: rawCat, unit_of_measure: 'kg', cost_price: 1.80, reorder_level: 20, item_type: 'RAW_MATERIAL' },
  ]
  const { data: insertedRaw, error: rawError } = await supabase.from('inventory_items').insert(rawMaterials).select()
  if (rawError) return { error: rawError.message }

  // 3. Menu Items
  const menuItems = [
    { tenant_id, name: 'Darjeeling First Flush (Pot)', item_code: 'MNU-TEA-01', category_id: bevCat, price: 8.50, menu_type: 'BEVERAGE' },
    { tenant_id, name: 'Masala Chai', item_code: 'MNU-TEA-02', category_id: bevCat, price: 4.50, menu_type: 'BEVERAGE' },
    { tenant_id, name: 'Cappuccino', item_code: 'MNU-COF-01', category_id: bevCat, price: 5.00, menu_type: 'BEVERAGE' },
    { tenant_id, name: 'Espresso', item_code: 'MNU-COF-02', category_id: bevCat, price: 3.50, menu_type: 'BEVERAGE' },
    { tenant_id, name: 'Butter Croissant', item_code: 'MNU-BAK-01', category_id: foodCat, price: 4.00, menu_type: 'FOOD' },
    { tenant_id, name: 'Club Sandwich', item_code: 'MNU-SND-01', category_id: foodCat, price: 12.00, menu_type: 'FOOD' },
  ]
  const { data: insertedMenu, error: menuError } = await supabase.from('menu_items').insert(menuItems).select()
  if (menuError) return { error: menuError.message }

  // 4. Recipes
  const recipes = [
    { tenant_id, menu_item_id: insertedMenu?.find(m => m.name === 'Masala Chai')?.id, name: 'Standard Masala Chai Recipe', instructions: 'Boil water, add CTC tea, add milk, simmer.', yield_quantity: 1, version_no: 1 },
    { tenant_id, menu_item_id: insertedMenu?.find(m => m.name === 'Cappuccino')?.id, name: 'Standard Cappuccino Recipe', instructions: 'Extract espresso, steam milk, pour.', yield_quantity: 1, version_no: 1 }
  ]
  const { data: insertedRecipes, error: recipeError } = await supabase.from('recipes').insert(recipes).select()
  if (recipeError) return { error: recipeError.message }

  // 5. Recipe Items
  const chaiRecipeId = insertedRecipes?.find(r => r.name === 'Standard Masala Chai Recipe')?.id
  const capRecipeId = insertedRecipes?.find(r => r.name === 'Standard Cappuccino Recipe')?.id

  const recipeItems = [
    { tenant_id, recipe_id: chaiRecipeId, inventory_item_id: insertedRaw?.find(r => r.sku === 'TEA-AS-CTC')?.id, quantity: 0.005, unit_of_measure: 'kg' },
    { tenant_id, recipe_id: chaiRecipeId, inventory_item_id: insertedRaw?.find(r => r.sku === 'MILK-WHL')?.id, quantity: 0.150, unit_of_measure: 'L' },
    { tenant_id, recipe_id: chaiRecipeId, inventory_item_id: insertedRaw?.find(r => r.sku === 'SGR-WHT')?.id, quantity: 0.010, unit_of_measure: 'kg' },
    { tenant_id, recipe_id: capRecipeId, inventory_item_id: insertedRaw?.find(r => r.sku === 'COF-ARA')?.id, quantity: 0.018, unit_of_measure: 'kg' },
    { tenant_id, recipe_id: capRecipeId, inventory_item_id: insertedRaw?.find(r => r.sku === 'MILK-WHL')?.id, quantity: 0.200, unit_of_measure: 'L' }
  ]
  const { error: riError } = await supabase.from('recipe_items').insert(recipeItems)
  if (riError) return { error: riError.message }

  // 6. Stock Adjustments (Initial Stock)
  const txs = insertedRaw?.map(item => ({
    tenant_id,
    inventory_item_id: item.id,
    transaction_type: 'PURCHASE',
    quantity_change: 100, // starting with 100 units of everything
    unit_cost: item.cost_price,
    reference_type: 'MANUAL_ADJUSTMENT',
    notes: 'Initial Seed Data Load',
    created_by: user.id
  })) || []
  const { error: txError } = await supabase.from('inventory_transactions').insert(txs)
  if (txError) return { error: txError.message }

  revalidatePath('/dashboard/inventory', 'layout')
  return { success: true }
}
