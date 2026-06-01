import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://nexusposbase.gyanodayniketan.cloud',
  'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc4MDE0NDE0MCwiZXhwIjo0OTM1ODE3NzQwLCJyb2xlIjoic2VydmljZV9yb2xlIn0.2DTaMCWandVYa4pAEOWV0zGLRAgvu11gyTJv8bHxWp4'
)

async function run() {
  const { data: users } = await supabase.auth.admin.listUsers()
  console.log('USERS:', users.users.length)
  
  const { data: profiles, error } = await supabase.from('profiles').select('*')
  console.log('PROFILES:', profiles?.length, error)
  if (profiles) console.dir(profiles, { depth: null })
}

run()
