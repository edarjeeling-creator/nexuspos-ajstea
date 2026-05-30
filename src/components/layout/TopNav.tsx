'use client'

import { useState, useEffect } from 'react'
import { Menu, Moon, Sun, User } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useTheme } from 'next-themes'
import { Sheet, SheetContent, SheetTrigger, SheetTitle } from '@/components/ui/sheet'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { createClient } from '@/utils/supabase/client'
import { useTenantStore } from '@/store/useTenantStore'
import { Sidebar } from './Sidebar' // Re-using Sidebar logic for mobile nav

export function TopNav() {
  const { setTheme, theme } = useTheme()
  const { outletId, setOutlet } = useTenantStore()
  const [outlets, setOutlets] = useState<any[]>([])
  const supabase = createClient()

  useEffect(() => {
    const fetchOutlets = async () => {
      const { data, error } = await supabase.from('outlets').select('id, name')
      if (!error && data) {
        setOutlets(data)
        if (!outletId && data.length > 0) {
          setOutlet(data[0].id)
        }
      }
    }
    fetchOutlets()
  }, [])

  return (
    <header className="flex h-[60px] items-center gap-4 border-b bg-white dark:bg-slate-950 px-6">
      <Sheet>
        <SheetTrigger asChild>
          <Button variant="outline" size="icon" className="shrink-0 md:hidden">
            <Menu className="h-5 w-5" />
            <span className="sr-only">Toggle navigation menu</span>
          </Button>
        </SheetTrigger>
        <SheetContent side="left" className="w-72 p-0">
          <SheetTitle className="sr-only">Navigation</SheetTitle>
          <div className="flex h-[60px] items-center border-b px-6">
             <span className="text-xl font-bold tracking-tight">NexusPOS AI</span>
          </div>
          {/* We will build a dedicated mobile nav later, using placeholder for now */}
          <div className="p-4 text-sm text-slate-500">Navigation...</div>
        </SheetContent>
      </Sheet>

      <div className="w-full flex-1">
        {/* Breadcrumbs could go here */}
      </div>

      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline" className="w-[200px] justify-start text-left font-normal">
            <span className="truncate">
              {outletId ? outlets.find(o => o.id === outletId)?.name || 'Loading...' : 'Select Outlet'}
            </span>
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent className="w-[200px]">
          {outlets.map((outlet) => (
            <DropdownMenuItem key={outlet.id} onClick={() => setOutlet(outlet.id)}>
              {outlet.name}
            </DropdownMenuItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>

      <Button
        variant="ghost"
        size="icon"
        onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
      >
        <Sun className="h-[1.2rem] w-[1.2rem] rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
        <Moon className="absolute h-[1.2rem] w-[1.2rem] rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
        <span className="sr-only">Toggle theme</span>
      </Button>

      <Button variant="ghost" size="icon" className="rounded-full bg-slate-100 dark:bg-slate-800">
        <User className="h-5 w-5 text-slate-600 dark:text-slate-300" />
        <span className="sr-only">Toggle user menu</span>
      </Button>
    </header>
  )
}
