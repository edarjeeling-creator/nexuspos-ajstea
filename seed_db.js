import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://nexusposbase.gyanodayniketan.cloud',
  'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc4MDE0NDE0MCwiZXhwIjo0OTM1ODE3NzQwLCJyb2xlIjoic2VydmljZV9yb2xlIn0.2DTaMCWandVYa4pAEOWV0zGLRAgvu11gyTJv8bHxWp4'
)

async function seedData() {
  console.log("Seeding Darjeeling Tea Shop Data...")
  
  const { data: users } = await supabase.auth.admin.listUsers()
  const user = users.users.find(u => u.email === 'edarjeeling@gmail.com')
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  const tenant_id = profile.tenant_id
  const outlet_id = profile.outlet_id

  const checkErr = (err, context) => { if (err) console.error(`Error in ${context}:`, err) }

  // Clean slate
  await supabase.from('recipe_items').delete().eq('tenant_id', tenant_id)
  await supabase.from('recipes').delete().eq('tenant_id', tenant_id)
  await supabase.from('menu_items').delete().eq('tenant_id', tenant_id)
  await supabase.from('inventory_transactions').delete().eq('tenant_id', tenant_id)
  await supabase.from('inventory_items').delete().eq('tenant_id', tenant_id)
  await supabase.from('categories').delete().eq('tenant_id', tenant_id)

  // Create Categories
  const { data: catTea, error: e1 } = await supabase.from('categories').insert({ tenant_id, name: 'Premium Teas', description: 'Darjeeling First Flush', display_order: 1 }).select().single()
  checkErr(e1, 'catTea')
  
  const { data: catCoffee, error: e2 } = await supabase.from('categories').insert({ tenant_id, name: 'Espresso Bar', description: 'Fresh coffee', display_order: 2 }).select().single()
  checkErr(e2, 'catCoffee')
  
  const { data: catBakery, error: e3 } = await supabase.from('categories').insert({ tenant_id, name: 'Bakery & Pastries', description: 'Baked goods', display_order: 3 }).select().single()
  checkErr(e3, 'catBakery')

  if (!catTea || !catCoffee || !catBakery) return;

  // Create Inventory Items (Raw Materials)
  const { data: invTeaLeaves, error: e4 } = await supabase.from('inventory_items').insert({ tenant_id, sku: 'RAW-TEA-001', name: 'Darjeeling First Flush Leaves', unit_of_measure: 'kg', item_type: 'RAW_MATERIAL' }).select().single()
  checkErr(e4, 'invTeaLeaves')
  
  const { data: invMilk, error: e5 } = await supabase.from('inventory_items').insert({ tenant_id, sku: 'RAW-MILK-001', name: 'Whole Milk', unit_of_measure: 'liter', item_type: 'RAW_MATERIAL' }).select().single()
  checkErr(e5, 'invMilk')
  
  const { data: invSugar, error: e6 } = await supabase.from('inventory_items').insert({ tenant_id, sku: 'RAW-SUGAR-001', name: 'White Sugar', unit_of_measure: 'kg', item_type: 'RAW_MATERIAL' }).select().single()
  checkErr(e6, 'invSugar')

  // Create Menu Items
  const { data: menuDarjTea, error: e7 } = await supabase.from('menu_items').insert({ tenant_id, category_id: catTea.id, name: 'First Flush Darjeeling Tea', description: 'Light, floral, spring tea', price: 4.50, is_available: true, tax_rate: 5, tax_inclusive: true }).select().single()
  checkErr(e7, 'menuDarjTea')
  
  const { data: menuLatte, error: e8 } = await supabase.from('menu_items').insert({ tenant_id, category_id: catCoffee.id, name: 'Classic Latte', description: 'Espresso with steamed milk', price: 5.00, is_available: true, tax_rate: 5, tax_inclusive: false }).select().single()
  checkErr(e8, 'menuLatte')
  
  const { data: menuCroissant, error: e9 } = await supabase.from('menu_items').insert({ tenant_id, category_id: catBakery.id, name: 'Butter Croissant', description: 'Flaky French pastry', price: 3.50, is_available: true, tax_rate: 5, tax_inclusive: false }).select().single()
  checkErr(e9, 'menuCroissant')

  // Create Recipes
  const { data: recDarjTea } = await supabase.from('recipes').insert({ tenant_id, menu_item_id: menuDarjTea.id, status: 'ACTIVE' }).select().single()
  await supabase.from('recipe_items').insert({ tenant_id, recipe_id: recDarjTea.id, inventory_item_id: invTeaLeaves.id, quantity: 0.005, unit_of_measure: 'kg' })

  const { data: recLatte } = await supabase.from('recipes').insert({ tenant_id, menu_item_id: menuLatte.id, status: 'ACTIVE' }).select().single()
  await supabase.from('recipe_items').insert({ tenant_id, recipe_id: recLatte.id, inventory_item_id: invMilk.id, quantity: 0.2, unit_of_measure: 'liter' })

  // Initial Stock (via inventory transaction)
  const { error: txErr } = await supabase.from('inventory_transactions').insert([
    { tenant_id, outlet_id, inventory_item_id: invTeaLeaves.id, transaction_type: 'ADJUSTMENT', quantity_change: 10, unit_cost: 150, reference_type: 'MANUAL_ADJUSTMENT', notes: 'Initial Stock' },
    { tenant_id, outlet_id, inventory_item_id: invMilk.id, transaction_type: 'ADJUSTMENT', quantity_change: 50, unit_cost: 1.2, reference_type: 'MANUAL_ADJUSTMENT', notes: 'Initial Stock' },
    { tenant_id, outlet_id, inventory_item_id: invSugar.id, transaction_type: 'ADJUSTMENT', quantity_change: 20, unit_cost: 0.8, reference_type: 'MANUAL_ADJUSTMENT', notes: 'Initial Stock' }
  ])
  checkErr(txErr, 'inventory_transactions')

  console.log("✅ Seeding completed successfully!")
}

seedData()
