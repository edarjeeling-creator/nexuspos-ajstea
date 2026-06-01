import { createClient } from '@supabase/supabase-js'

const supabaseAdmin = createClient(
  'https://nexusposbase.gyanodayniketan.cloud',
  'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc4MDE0NDE0MCwiZXhwIjo0OTM1ODE3NzQwLCJyb2xlIjoic2VydmljZV9yb2xlIn0.2DTaMCWandVYa4pAEOWV0zGLRAgvu11gyTJv8bHxWp4'
)

async function listUsers() {
  const { data: users, error } = await supabaseAdmin.auth.admin.listUsers()
  if (error) {
    console.error('Error fetching users:', error)
    return
  }
  
  if (users.users.length === 0) {
    console.log("No users found in the database.")
    return
  }

  console.log("--- REGISTERED USERS ---")
  users.users.forEach(u => {
    console.log(`Email: ${u.email} (ID: ${u.id})`)
  })
}

listUsers()
