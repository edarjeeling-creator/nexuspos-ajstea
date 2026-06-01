import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://nexusposbase.gyanodayniketan.cloud',
  'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc4MDE0NDE0MCwiZXhwIjo0OTM1ODE3NzQwLCJyb2xlIjoic2VydmljZV9yb2xlIn0.2DTaMCWandVYa4pAEOWV0zGLRAgvu11gyTJv8bHxWp4'
)

async function validatePOS() {
  console.log("Starting POS E2E Validation...")
  
  const { data: users } = await supabase.auth.admin.listUsers()
  const user = users.users.find(u => u.email === 'edarjeeling@gmail.com')
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  const tenant_id = profile.tenant_id
  const outlet_id = profile.outlet_id

  let passed = 0;
  let failed = 0;
  const dbRecords = [];
  const stockChanges = [];

  const assert = (condition, message) => {
    if (condition) {
      console.log(`✅ PASS: ${message}`);
      passed++;
    } else {
      console.error(`❌ FAIL: ${message}`);
      failed++;
    }
  }

  // 1. Fetch Master Data
  const { data: items } = await supabase.from('menu_items').select('*').eq('tenant_id', tenant_id)
  const teaItem = items.find(i => i.name === 'First Flush Darjeeling Tea')
  const latteItem = items.find(i => i.name === 'Classic Latte')
  assert(teaItem && latteItem, "Menu items loaded")

  // 2. Fetch Initial Inventory
  const { data: invItems } = await supabase.from('inventory_items').select('id, name').eq('tenant_id', tenant_id)
  const milk = invItems.find(i => i.name === 'Whole Milk')
  const leaves = invItems.find(i => i.name === 'Darjeeling First Flush Leaves')
  
  const { data: initialStockTx } = await supabase.from('inventory_transactions').select('inventory_item_id, quantity_change').eq('tenant_id', tenant_id)
  const getStock = (itemId) => initialStockTx.filter(tx => tx.inventory_item_id === itemId).reduce((acc, curr) => acc + curr.quantity_change, 0)
  const initialMilkStock = getStock(milk.id)
  const initialLeavesStock = getStock(leaves.id)

  assert(initialMilkStock === 50, `Initial Milk Stock is 50 (actual: ${initialMilkStock})`)

  // 3. Create Order
  const orderNumber = 'ORD-' + Math.floor(Math.random() * 100000)
  const { data: order, error: orderErr } = await supabase.from('orders').insert({
    tenant_id, outlet_id, order_number: orderNumber, user_id: user.id,
    order_type: 'DINE_IN', status: 'COMPLETED', payment_status: 'PAID',
    subtotal: 14.00, tax_total: 0.70, grand_total: 14.70, inventory_processed: true
  }).select().single()
  assert(!orderErr && order, "Order inserted successfully")
  if (order) dbRecords.push(`Order: ${order.id}`)

  // 4. Create Order Items
  const { data: orderItem1, error: itemErr1 } = await supabase.from('order_items').insert({
    tenant_id, order_id: order.id, menu_item_id: teaItem.id, quantity: 2,
    unit_price: 4.50, subtotal: 9.00, tax_amount: 0.45, total_price: 9.45, status: 'SERVED'
  }).select().single()
  const { data: orderItem2, error: itemErr2 } = await supabase.from('order_items').insert({
    tenant_id, order_id: order.id, menu_item_id: latteItem.id, quantity: 1,
    unit_price: 5.00, subtotal: 5.00, tax_amount: 0.25, total_price: 5.25, status: 'SERVED'
  }).select().single()
  assert(!itemErr1 && !itemErr2, "Order Items inserted successfully")
  if (orderItem1 && orderItem2) dbRecords.push(`Order Items: 2 created`)

  // 5. Create Payment
  const { data: payment, error: payErr } = await supabase.from('payments').insert({
    tenant_id, outlet_id, order_id: order.id, amount: 14.70, payment_method: 'CREDIT_CARD', status: 'COMPLETED'
  }).select().single()
  assert(!payErr && payment, "Payment recorded successfully")
  if (payment) dbRecords.push(`Payment: ${payment.id} (CREDIT_CARD)`)

  // 6. Deduct Inventory (Simulate RPC / Backend logic)
  // 2 Teas = 2 * 0.005kg = 0.01kg
  // 1 Latte = 1 * 0.2L = 0.2L
  const { data: tx1, error: txErr1 } = await supabase.from('inventory_transactions').insert({
    tenant_id, outlet_id, inventory_item_id: leaves.id, transaction_type: 'SALE', quantity_change: -0.01, unit_cost: 150, reference_type: 'ORDER', reference_id: order.id
  }).select().single()
  const { data: tx2, error: txErr2 } = await supabase.from('inventory_transactions').insert({
    tenant_id, outlet_id, inventory_item_id: milk.id, transaction_type: 'SALE', quantity_change: -0.2, unit_cost: 1.2, reference_type: 'ORDER', reference_id: order.id
  }).select().single()
  assert(!txErr1 && !txErr2, "Inventory deducted through transactions")
  
  stockChanges.push(`Darjeeling Leaves: -0.01 kg`)
  stockChanges.push(`Whole Milk: -0.2 L`)

  // 7. Verify Final Stock
  const { data: finalStockTx } = await supabase.from('inventory_transactions').select('inventory_item_id, quantity_change').eq('tenant_id', tenant_id)
  const getFinalStock = (itemId) => finalStockTx.filter(tx => tx.inventory_item_id === itemId).reduce((acc, curr) => acc + curr.quantity_change, 0)
  
  const finalMilk = getFinalStock(milk.id);
  const finalLeaves = getFinalStock(leaves.id);
  assert(finalMilk === 49.8, `Milk stock is accurately 49.8 (actual: ${finalMilk})`)
  assert(finalLeaves === 9.99, `Leaves stock is accurately 9.99 (actual: ${finalLeaves})`)

  console.log("\n--- VALIDATION REPORT ---")
  console.log(`Passed: ${passed}`)
  console.log(`Failed: ${failed}`)
  console.log("\nDB Records Created:")
  dbRecords.forEach(r => console.log(`- ${r}`))
  console.log("\nStock Deductions Simulated:")
  stockChanges.forEach(r => console.log(`- ${r}`))
}

validatePOS()
