import { createClient } from '@supabase/supabase-js'
import 'dotenv/config'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase environment variables')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseKey)

const businesses = [
  { name: "AJS Tea and More", type: "TEASHOP" },
  { name: "Cafe Demo", type: "CAFE" },
  { name: "Restaurant Demo", type: "RESTAURANT" }
]

async function seedDemos() {
  console.log("--- Seeding Pilot Demo Businesses ---")
  
  for (const b of businesses) {
    // 1. Create Tenant
    const { data: tenant, error: tErr } = await supabase.from('tenants').insert({
      name: b.name
    }).select().single()

    if (tErr || !tenant) {
      console.error(`Failed to create tenant ${b.name}:`, tErr?.message)
      continue
    }

    // 2. Create Outlet
    const { error: oErr } = await supabase.from('outlets').insert({
      tenant_id: tenant.id,
      name: `${b.name} - Main Branch`,
      address: '123 Pilot Street, Pilot City',
      phone: '555-0192'
    })

    if (oErr) {
      console.error(`Failed to create outlet for ${b.name}:`, oErr.message)
    } else {
      console.log(`✅ Provisioned: ${b.name} (Tenant ID: ${tenant.id})`)
    }
  }
  
  console.log("--- Seeding Complete ---")
}

seedDemos().catch(console.error)
