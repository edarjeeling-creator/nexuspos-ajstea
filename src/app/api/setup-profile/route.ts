import { createClient } from '@supabase/supabase-js'
import { NextResponse } from 'next/server'

export async function POST(req: Request) {
  try {
    const { userId, email } = await req.json()
    
    if (!userId) return NextResponse.json({ error: 'Missing userId' }, { status: 400 })

    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )

    // 1. Check if profile already exists
    const { data: existingProfile } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('id', userId)
      .single()

    if (existingProfile) {
      return NextResponse.json({ success: true, message: 'Profile already exists' })
    }

    // 2. Create Tenant
    const { data: tenant, error: tenantErr } = await supabaseAdmin
      .from('tenants')
      .insert({ name: `${email.split('@')[0]}'s Business` })
      .select()
      .single()
      
    if (tenantErr || !tenant) throw tenantErr || new Error('Tenant creation failed')

    // 3. Create Outlet
    const { data: outlet, error: outletErr } = await supabaseAdmin
      .from('outlets')
      .insert({ tenant_id: tenant.id, name: 'Main Outlet' })
      .select()
      .single()

    if (outletErr || !outlet) throw outletErr || new Error('Outlet creation failed')

    // 4. Create Profile
    const { error: profileErr } = await supabaseAdmin
      .from('profiles')
      .insert({
        id: userId,
        tenant_id: tenant.id,
        outlet_id: outlet.id,
        full_name: email.split('@')[0],
        status: 'ACTIVE'
      })

    if (profileErr) throw profileErr

    // 5. Seed Roles
    await supabaseAdmin.from('roles').insert([
      { tenant_id: tenant.id, name: 'OWNER', description: 'Full access' }
    ])

    const { data: ownerRole } = await supabaseAdmin
      .from('roles')
      .select('id')
      .eq('tenant_id', tenant.id)
      .eq('name', 'OWNER')
      .single()

    if (ownerRole) {
      await supabaseAdmin.from('user_roles').insert({
        user_id: userId,
        role_id: ownerRole.id,
        outlet_id: outlet.id
      })
    }

    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('Setup profile error:', error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
