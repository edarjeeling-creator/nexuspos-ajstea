import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://nexusposbase.gyanodayniketan.cloud',
  'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc4MDE0NDE0MCwiZXhwIjo0OTM1ODE3NzQwLCJyb2xlIjoiYW5vbiJ9.ifB1o8VU-BeHVm_XvHRgwNX0m-fOQu_WYm37Khcc2rI'
)

async function test() {
  const email = 'edarj@example.com' // Not real email, but we need to log in
  // Let's just use the anon key with a JWT if we can?
  // We can't easily mimic the frontend user without their password.

  // Let's just query profiles directly.
  const { data, error } = await supabase.from('profiles').select('*').limit(1)
  console.log('Anon query:', error)
}
test()
