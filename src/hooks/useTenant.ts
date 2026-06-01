import { useState, useEffect } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'

export function useTenant() {
  const [tenantId, setTenantId] = useState<string | null>(null)
  const [outletId, setOutletId] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const supabase = createClientComponentClient()

  useEffect(() => {
    async function loadTenant() {
      try {
        const { data: { user } } = await supabase.auth.getUser()
        if (!user) return

        const { data: outletUser } = await supabase
          .from('outlet_users')
          .select('outlet_id, outlets(tenant_id)')
          .eq('user_id', user.id)
          .limit(1)
          .single()

        if (outletUser) {
          setOutletId(outletUser.outlet_id)
          // @ts-ignore
          setTenantId(outletUser.outlets?.tenant_id)
        }
      } catch (err) {
        console.error('Failed to load tenant details', err)
      } finally {
        setIsLoading(false)
      }
    }
    loadTenant()
  }, [supabase])

  return { tenantId, outletId, isLoading }
}
