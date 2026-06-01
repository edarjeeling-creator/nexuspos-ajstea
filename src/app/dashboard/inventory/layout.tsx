'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { LayoutDashboard, Tags, Package, ListMinus, Layers, Settings } from 'lucide-react'

const TABS = [
  { name: 'Overview', href: '/dashboard/inventory', icon: LayoutDashboard },
  { name: 'Categories', href: '/dashboard/inventory/categories', icon: Tags },
  { name: 'Raw Materials', href: '/dashboard/inventory/raw-materials', icon: Package },
  { name: 'Menu Items', href: '/dashboard/inventory/menu-items', icon: ListMinus },
  { name: 'Stock Tracking', href: '/dashboard/inventory/stock', icon: Layers },
  { name: 'Settings', href: '/dashboard/inventory/settings', icon: Settings },
]

export default function InventoryLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex border-b border-slate-200 dark:border-slate-800 overflow-x-auto pb-[-1px]">
        {TABS.map((tab) => {
          const isActive = pathname === tab.href || (tab.href !== '/dashboard/inventory' && pathname.startsWith(tab.href))
          
          return (
            <Link
              key={tab.name}
              href={tab.href}
              className={cn(
                "flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-medium whitespace-nowrap transition-colors",
                isActive
                  ? "border-indigo-600 text-indigo-600 dark:border-indigo-400 dark:text-indigo-400"
                  : "border-transparent text-slate-500 hover:border-slate-300 hover:text-slate-700 dark:text-slate-400 dark:hover:border-slate-700 dark:hover:text-slate-300"
              )}
            >
              <tab.icon className="h-4 w-4" />
              {tab.name}
            </Link>
          )
        })}
      </div>
      
      <div>
        {children}
      </div>
    </div>
  )
}
