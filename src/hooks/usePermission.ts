'use client'

import { useTenantStore } from '@/store/useTenantStore'
import { Permission, Module, Action } from '@/lib/constants/permissions'

export function usePermission() {
  const { permissions } = useTenantStore()

  const hasPermission = (permission: Permission): boolean => {
    if (permissions.includes('*')) return true;
    
    // Check for exact match or module wildcard
    if (permissions.includes(permission)) return true;
    
    const [module] = permission.split('.');
    if (permissions.includes(`${module}.*` as Permission)) return true;
    
    return false;
  }

  const hasModuleAccess = (module: Module): boolean => {
    if (permissions.includes('*')) return true;
    if (permissions.includes(`${module}.*` as Permission)) return true;
    
    // Check if they have ANY permission in this module
    return permissions.some(p => p.startsWith(`${module}.`));
  }

  return { hasPermission, hasModuleAccess }
}
