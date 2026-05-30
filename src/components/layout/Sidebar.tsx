'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { usePermission } from '@/hooks/usePermission'
import { 
  LayoutDashboard, ShoppingCart, Package, Users, 
  UserCheck, Box, Calculator, BarChart3, 
  Bell, Plug, Settings 
} from 'lucide-react'
import { cn } from '@/lib/utils'

const NAVIGATION_GROUPS = [
  {
    group: 'Operations',
    items: [
      { name: 'Overview', href: '/dashboard/overview', icon: LayoutDashboard, module: 'pos' },
      { name: 'POS', href: '/dashboard/pos', icon: ShoppingCart, module: 'pos' },
      { name: 'Inventory', href: '/dashboard/inventory', icon: Package, module: 'inventory' },
    ]
  },
  {
    group: 'Customers',
    items: [
      { name: 'CRM', href: '/dashboard/crm', icon: Users, module: 'crm' },
    ]
  },
  {
    group: 'Business',
    items: [
      { name: 'HRMS', href: '/dashboard/hrms', icon: UserCheck, module: 'hrms' },
      { name: 'ERP', href: '/dashboard/erp', icon: Box, module: 'erp' },
      { name: 'Accounting', href: '/dashboard/accounting', icon: Calculator, module: 'accounting' },
    ]
  },
  {
    group: 'Insights',
    items: [
      { name: 'Analytics', href: '/dashboard/analytics', icon: BarChart3, module: 'analytics' },
    ]
  },
  {
    group: 'Platform',
    items: [
      { name: 'Notifications', href: '/dashboard/notifications', icon: Bell, module: 'notifications' },
      { name: 'Integrations', href: '/dashboard/integrations', icon: Plug, module: 'integrations' },
      { name: 'Settings', href: '/dashboard/settings', icon: Settings, module: 'settings' },
    ]
  }
] as const;

export function Sidebar() {
  const pathname = usePathname()
  const { hasModuleAccess } = usePermission()

  return (
    <div className="hidden border-r bg-slate-50/40 dark:bg-slate-900/40 md:block md:w-64 lg:w-72 flex-shrink-0">
      <div className="flex h-full max-h-screen flex-col gap-2">
        <div className="flex h-[60px] items-center border-b px-6">
          <Link className="flex items-center gap-2 font-bold" href="/dashboard/overview">
            <span className="text-xl tracking-tight">NexusPOS AI</span>
          </Link>
        </div>
        <div className="flex-1 overflow-auto py-4">
          <nav className="grid items-start px-4 text-sm font-medium">
            {NAVIGATION_GROUPS.map((group) => {
              // Filter items by permission
              const visibleItems = group.items.filter(item => hasModuleAccess(item.module as any))
              
              if (visibleItems.length === 0) return null;

              return (
                <div key={group.group} className="mb-6">
                  <h4 className="mb-2 px-2 text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
                    {group.group}
                  </h4>
                  {visibleItems.map((item) => {
                    const isActive = pathname.startsWith(item.href)
                    return (
                      <Link
                        key={item.name}
                        href={item.href}
                        className={cn(
                          "flex items-center gap-3 rounded-lg px-3 py-2 transition-all hover:text-slate-900 dark:hover:text-white",
                          isActive 
                            ? "bg-slate-200 text-slate-900 dark:bg-slate-800 dark:text-white font-medium shadow-sm" 
                            : "text-slate-600 dark:text-slate-400"
                        )}
                      >
                        <item.icon className="h-4 w-4" />
                        {item.name}
                      </Link>
                    )
                  })}
                </div>
              )
            })}
          </nav>
        </div>
      </div>
    </div>
  )
}
