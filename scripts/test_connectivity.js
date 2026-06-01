const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.production' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Missing Supabase Environment Variables.");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);
const supabaseAdmin = createClient(supabaseUrl, serviceKey);

async function testConnectivity() {
  console.log("========================================");
  console.log("NEXUSPOS AI - CONNECTIVITY TEST");
  console.log("========================================\n");

  console.log(`Connecting to: ${supabaseUrl}`);

  // Test 1: Basic connection via API (Read from organizations)
  console.log("\n▶ Test 1: Testing basic database connectivity (Anon Key)...");
  try {
    const { data, error } = await supabase.from('organizations').select('id, name').limit(1);
    
    if (error) {
      if (error.code === 'PGRST116' || error.message.includes('row-level security')) {
         console.log("✅ Connection successful, but blocked by RLS (Expected behavior for Anon key).");
      } else if (error.code === '42P01') {
         console.error("❌ Connection successful, but table 'organizations' does not exist. Run migrations first.");
      } else {
         console.error(`❌ Connection failed. Error: ${error.message}`);
      }
    } else {
      console.log(`✅ Connection successful. Retrieved data: ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error(`❌ Connection failed. Exception: ${err.message}`);
  }

  // Test 2: Service Role Key Check
  console.log("\n▶ Test 2: Testing Service Role bypassing RLS (Service Role Key)...");
  try {
    const { data, error } = await supabaseAdmin.from('organizations').select('id, name').limit(1);
    
    if (error) {
       console.error(`❌ Service Role query failed. Error: ${error.message}`);
    } else {
       console.log(`✅ Service Role connection successful. Retrieved data: ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error(`❌ Service Role connection failed. Exception: ${err.message}`);
  }

}

testConnectivity();
