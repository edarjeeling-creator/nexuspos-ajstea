'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/utils/supabase/client'
import { useTenantStore } from '@/store/useTenantStore'
import { Permission } from '@/lib/constants/permissions'

export function TenantProvider({ children }: { children: React.ReactNode }) {
  const { setTenant, tenantId } = useTenantStore()
  const [isSettingUp, setIsSettingUp] = useState(false)
  const [setupError, setSetupError] = useState<string | null>(null)
  
  useEffect(() => {
    // Only fetch if we don't have it in memory yet
    if (tenantId) return;

    const fetchTenantData = async () => {
      const supabase = createClient()
      
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return;

      // 1. Get Profile
      let { data: profile, error: pError } = await supabase
        .from('profiles')
        .select('tenant_id, outlet_id')
        .eq('id', user.id)
        .single()
        
      if (!profile) {
        // Auto-setup the user profile if it's missing (happens on first login if trigger failed)
        setIsSettingUp(true)
        try {
          const res = await fetch('/api/setup-profile', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userId: user.id, email: user.email })
          })
          
          if (!res.ok) throw new Error('Failed to setup profile')
            
          // Re-fetch profile after setup
          const { data: newProfile, error: refetchErr } = await supabase
            .from('profiles')
            .select('tenant_id, outlet_id')
            .eq('id', user.id)
            .single()
            
          if (refetchErr || !newProfile) {
            setSetupError(`Profile setup completed but could not load it. Error: ${refetchErr ? refetchErr.message + ' (' + refetchErr.code + ')' : 'No profile found'}`)
            setIsSettingUp(false)
            return;
          }
          
          profile = newProfile;
          setIsSettingUp(false)
        } catch (err: any) {
          console.error(err)
          setSetupError('Could not initialize your account. Please contact support.')
          setIsSettingUp(false)
          return;
        }
      }

      // 2. Get Permissions (Mocking full access for now)
      const permissions: Permission[] = ['*']; 

      setTenant(profile.tenant_id, profile.outlet_id, permissions)
    }

    fetchTenantData()
  }, [tenantId, setTenant])

  if (isSettingUp) {
    return <div className="flex min-h-screen items-center justify-center bg-slate-50 dark:bg-slate-950">
      <div className="text-center p-8 bg-white dark:bg-slate-900 rounded-xl shadow-sm border border-slate-200 dark:border-slate-800">
        <h2 className="text-lg font-semibold mb-2">Setting up your account...</h2>
        <p className="text-sm text-slate-500">Just a moment while we initialize your workspace.</p>
      </div>
    </div>
  }

  if (setupError) {
    return <div className="flex min-h-screen items-center justify-center p-4">
      <div className="bg-red-50 text-red-600 p-4 rounded-lg border border-red-200">
        {setupError}
      </div>
    </div>
  }

  return <>{children}</>
}
