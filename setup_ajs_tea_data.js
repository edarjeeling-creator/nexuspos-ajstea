const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("Missing Supabase credentials in .env.local");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function run() {
  try {
    console.log("Fetching demo tenant 'ajsteaandmore'...");
    const { data: tenant, error: tenantErr } = await supabase
      .from('tenants')
      .select('id')
      .eq('name', 'AJS Tea and More')
      .single();

    if (tenantErr || !tenant) {
      console.error("Failed to find tenant. Has the demo setup script been run?", tenantErr);
      return;
    }

    const tenantId = tenant.id;

    // Fetch primary outlet and warehouse
    const { data: outlet } = await supabase.from('outlets').select('id').eq('tenant_id', tenantId).limit(1).single();
    const { data: warehouse } = await supabase.from('warehouses').select('id').eq('tenant_id', tenantId).limit(1).single();
    const { data: category } = await supabase.from('categories').select('id').eq('tenant_id', tenantId).limit(1).single();

    if (!outlet || !warehouse || !category) {
      console.error("Missing basic entities for tenant.");
      return;
    }

    const products = [
      { name: "Darjeeling First Flush (Bulk)", barcode: "BULK-DFF-001", type: "RAW_MATERIAL", uom: "kg", cost: 1200, price: 0, initialStock: 50 },
      { name: "Green Tea (Bulk)", barcode: "BULK-GT-001", type: "RAW_MATERIAL", uom: "kg", cost: 600, price: 0, initialStock: 100 },
      
      { name: "Darjeeling First Flush 100g", barcode: "DFF-100G-001", type: "RETAIL", uom: "piece", cost: 150, price: 299, initialStock: 20 },
      { name: "Darjeeling First Flush 250g", barcode: "DFF-250G-001", type: "RETAIL", uom: "piece", cost: 350, price: 699, initialStock: 15 },
      { name: "Darjeeling First Flush 500g", barcode: "DFF-500G-001", type: "RETAIL", uom: "piece", cost: 650, price: 1299, initialStock: 10 },
      
      { name: "Green Tea 100g", barcode: "GT-100G-001", type: "RETAIL", uom: "piece", cost: 80, price: 199, initialStock: 30 },
      { name: "Green Tea 250g", barcode: "GT-250G-001", type: "RETAIL", uom: "piece", cost: 180, price: 449, initialStock: 25 },
      { name: "Green Tea 500g", barcode: "GT-500G-001", type: "RETAIL", uom: "piece", cost: 340, price: 799, initialStock: 15 }
    ];

    console.log("Seeding products...");
    for (const p of products) {
      // 1. Insert Inventory Item
      const { data: invItem, error: invErr } = await supabase.from('inventory_items').insert([{
        tenant_id: tenantId,
        category_id: category.id,
        item_code: p.barcode,
        name: p.name,
        description: `Premium ${p.name}`,
        item_type: p.type,
        unit_of_measure: p.uom,
        barcode: p.barcode,
        unit_cost: p.cost,
        stock_quantity: 0 // Will adjust via ledger
      }]).select().single();

      if (invErr) {
        if (invErr.code === '23505') {
            console.log(`Skipping ${p.name}, already exists.`);
            continue;
        } else {
            console.error(`Error inserting ${p.name}`, invErr);
            continue;
        }
      }

      // 2. Adjust Stock via ledger
      await supabase.from('inventory_transactions').insert([{
        tenant_id: tenantId,
        outlet_id: outlet.id,
        inventory_item_id: invItem.id,
        transaction_type: 'ADJUSTMENT',
        quantity_change: p.initialStock,
        unit_cost: p.cost,
        reference_type: 'INITIAL_STOCK',
        notes: 'Initial seed stock'
      }]);

      // 3. Create POS Menu Item (if Retail)
      if (p.type === 'RETAIL') {
        await supabase.from('menu_items').insert([{
          tenant_id: tenantId,
          category_id: category.id,
          item_code: p.barcode,
          name: p.name,
          menu_type: 'RETAIL',
          price: p.price,
          cost_estimate: p.cost,
          tax_category: 'STANDARD'
        }]);
      }
    }

    console.log("Demo data setup complete.");
  } catch (err) {
    console.error("Script failed:", err);
  }
}

run();
