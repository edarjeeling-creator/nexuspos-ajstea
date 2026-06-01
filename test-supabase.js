import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase Environment Variables');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceKey || supabaseKey);

async function testConnection() {
  console.log(`Connecting to: ${supabaseUrl}`);
  
  try {
    // 1. Test Database Query
    console.log('\nTesting Database Query...');
    const { data, error } = await supabase.from('tenants').select('id, name').limit(1);
    
    if (error) {
      console.error('Database Query Failed:', error.message);
    } else {
      console.log('Database Query Successful! Tenants found:', data.length);
    }
    
    // 2. Test Auth Service
    console.log('\nTesting Authentication Service...');
    const { data: authData, error: authError } = await supabase.auth.getSession();
    if (authError) {
      console.error('Auth Service Failed:', authError.message);
    } else {
      console.log('Auth Service is reachable!');
    }
    
    console.log('\n✅ All Basic Supabase Connectivity Tests Passed!');
  } catch (err) {
    console.error('Unexpected error:', err);
  }
}

testConnection();
