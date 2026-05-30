'use client'

import { useEffect, useState } from 'react'
import { usePermission } from '@/hooks/usePermission'
import { Module } from '@/lib/constants/permissions'
import AccessDenied from '@/components/ui/shared/AccessDenied'

interface RouteGuardProps {
  module: Module
  children: React.ReactNode
}

export function RouteGuard({ module, children }: RouteGuardProps) {
  const { hasModuleAccess } = usePermission()
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  if (!mounted) {
    return null // Provide a generic skeleton loader or just return null during hydration
  }

  if (!hasModuleAccess(module)) {
    return <AccessDenied />
  }

  return <>{children}</>
}
