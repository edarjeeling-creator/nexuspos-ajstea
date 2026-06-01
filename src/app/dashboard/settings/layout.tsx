'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Building2, Receipt, Percent, ShieldCheck } from 'lucide-react'
import { cn } from '@/lib/utils'

const SETTINGS_NAV = [
  { name: 'Business Settings', href: '/dashboard/settings/business', icon: Building2 },
  { name: 'Receipt Settings', href: '/dashboard/settings/receipts', icon: Receipt },
  { name: 'GST & Tax Settings', href: '/dashboard/settings/taxes', icon: Percent },
  { name: 'Roles & Permissions', href: '/dashboard/settings/rbac', icon: ShieldCheck },
]

export default function SettingsLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()

  return (
    <div className="flex h-[calc(100vh-4rem)] flex-col md:flex-row gap-6 p-6">
      <div className="md:w-64 flex-shrink-0">
        <h2 className="mb-4 text-xl font-bold tracking-tight">Settings</h2>
        <nav className="flex flex-col gap-1">
          {SETTINGS_NAV.map((item) => {
            const isActive = pathname.startsWith(item.href)
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                  isActive
                    ? "bg-slate-100 text-slate-900 dark:bg-slate-800 dark:text-white"
                    : "text-slate-600 hover:bg-slate-50 hover:text-slate-900 dark:text-slate-400 dark:hover:bg-slate-800/50 dark:hover:text-white"
                )}
              >
                <item.icon className="h-4 w-4" />
                {item.name}
              </Link>
            )
          })}
        </nav>
      </div>
      <div className="flex-1 overflow-auto bg-white dark:bg-slate-950 rounded-lg border border-slate-200 dark:border-slate-800 shadow-sm p-6">
        {children}
      </div>
    </div>
  )
}
