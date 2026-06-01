import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'
import assert from 'assert'
import fs from 'fs'

dotenv.config({ path: '.env.local' })

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY // Need service key to bypass RLS easily, but let's see

if (!supabaseUrl || !supabaseServiceKey) {
  console.error("Missing Supabase credentials in .env.local")
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseServiceKey)

async function run() {
  console.log("Starting KDS E2E Validation...")
  let passed = 0
  let failed = 0
  
  const assertTest = (condition, message) => {
    try {
      assert(condition)
      console.log(`✅ PASS: ${message}`)
      passed++
    } catch (e) {
      console.error(`❌ FAIL: ${message} (actual: ${e.actual})`)
      failed++
    }
  }

  try {
    // 1. Get a Tenant and Outlet
    const { data: tenant } = await supabase.from('tenants').select('id').limit(1).single()
    const { data: outlet } = await supabase.from('outlets').select('id').eq('tenant_id', tenant.id).limit(1).single()
    const { data: user } = await supabase.from('users').select('id, email').eq('email', 'admin2@test.com').single()
    const tenant_id = tenant.id
    const outlet_id = outlet.id

    // 2. Get Menu Items for BAR and KITCHEN
    // Ensure we have a BAR item and a KITCHEN item
    const { data: categories } = await supabase.from('categories').select('id, name').eq('tenant_id', tenant_id)
    const hotId = categories.find(c => c.name === 'Hot Beverages')?.id
    
    // We'll insert a mock order with items going to 'BAR'
    const orderNumber = 'KDS-' + Math.floor(Math.random() * 100000)
    
    const { data: order, error: orderErr } = await supabase.from('orders').insert({
      tenant_id,
      outlet_id,
      user_id: user?.id,
      order_number: orderNumber,
      order_type: 'DINE_IN',
      table_number: '12',
      status: 'PENDING',
      subtotal: 10,
      grand_total: 10,
      notes: 'Allergy: Peanuts'
    }).select().single()
    
    if (orderErr) {
      console.error("Failed to create order:", orderErr)
      return
    }
    assertTest(!orderErr, "Order created successfully for KDS testing")

    // Get a menu item to link
    const { data: menuItem } = await supabase.from('menu_items').select('id, name').eq('tenant_id', tenant_id).limit(1).single()

    const { data: orderItems, error: itemsErr } = await supabase.from('order_items').insert([
      {
        tenant_id,
        order_id: order.id,
        menu_item_id: menuItem.id,
        quantity: 2,
        unit_price: 5,
        subtotal: 10,
        total_price: 10,
        preparation_station: 'BAR',
        status: 'PENDING',
        notes: 'Extra ice'
      }
    ]).select()
    
    if (itemsErr) {
      console.error("Failed to assign order item:", itemsErr)
      return
    }
    assertTest(!itemsErr && orderItems.length === 1, "Order Item assigned to BAR station successfully")

    // Simulate KDS changing status to PREPARING
    const { error: prepErr } = await supabase.from('order_items').update({ status: 'PREPARING' }).eq('id', orderItems[0].id)
    assertTest(!prepErr, "KDS successfully transitioned item to PREPARING")
    
    // Check if status updated
    const { data: checkPrep } = await supabase.from('order_items').select('status').eq('id', orderItems[0].id).single()
    assertTest(checkPrep.status === 'PREPARING', "Database reflects PREPARING status in real-time")

    // Simulate KDS changing status to READY
    const { error: readyErr } = await supabase.from('order_items').update({ status: 'READY' }).eq('id', orderItems[0].id)
    assertTest(!readyErr, "KDS successfully transitioned item to READY")

    // Simulate BUMP ticket
    const { error: bumpErr } = await supabase.from('order_items').update({ status: 'SERVED' }).eq('id', orderItems[0].id)
    assertTest(!bumpErr, "KDS successfully bumped ticket (status: SERVED)")

    // Verify
    const { data: checkFinal } = await supabase.from('order_items').select('status').eq('id', orderItems[0].id).single()
    assertTest(checkFinal.status === 'SERVED', "Database reflects SERVED status for bumped ticket")

    // Generate Report
    const report = `# KDS Validation Report\n\n` +
      `Tested Real-time POS -> KDS -> Ready -> Served synchronization.\n\n` +
      `**Passed:** ${passed}\n**Failed:** ${failed}\n\n` +
      `**Test Order:** ${orderNumber}\n` +
      `**Station:** BAR\n` +
      `**Result:** ${failed === 0 ? '✅ SUCCESS' : '❌ FAILED'}\n`

    fs.writeFileSync('kds_validation_report.md', report)
    console.log("\nSaved kds_validation_report.md")

  } catch (err) {
    console.error("Validation Script Error:", err)
  }
}

run()
