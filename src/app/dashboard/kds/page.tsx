'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Flame, Droplet, Martini, CakeSlice, CheckSquare, ArrowRight } from 'lucide-react'
import Link from 'next/link'

const STATIONS = [
  { id: '1', name: 'Hot Grill', type: 'GRILL', icon: Flame, color: 'text-orange-500', border: 'border-orange-500/50', hover: 'hover:border-orange-500' },
  { id: '2', name: 'Fryer Station', type: 'FRYER', icon: Droplet, color: 'text-amber-500', border: 'border-amber-500/50', hover: 'hover:border-amber-500' },
  { id: '3', name: 'Main Bar', type: 'BAR', icon: Martini, color: 'text-blue-500', border: 'border-blue-500/50', hover: 'hover:border-blue-500' },
  { id: '4', name: 'Desserts', type: 'DESSERT', icon: CakeSlice, color: 'text-pink-500', border: 'border-pink-500/50', hover: 'hover:border-pink-500' },
  { id: '5', name: 'Expo Line', type: 'EXPO', icon: CheckSquare, color: 'text-indigo-500', border: 'border-indigo-500/50', hover: 'hover:border-indigo-500' },
]

export default function KDSStationSelection() {
  return (
    <RouteGuard module="pos">
      <div className="flex flex-col gap-6 max-w-5xl mx-auto py-8">
        <div className="text-center space-y-2">
          <h1 className="text-4xl font-bold tracking-tight text-slate-900 dark:text-white">Select KDS Station</h1>
          <p className="text-slate-500 dark:text-slate-400">
            Choose the preparation station for this display terminal.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mt-8">
          {STATIONS.map(station => {
            const Icon = station.icon
            return (
              <Link key={station.id} href={`/dashboard/kds/${station.id}`}>
                <Card className={`h-full cursor-pointer transition-all duration-200 border-2 border-transparent bg-slate-50 dark:bg-slate-900 ${station.hover} hover:shadow-lg group`}>
                  <CardContent className="flex flex-col items-center justify-center p-8 text-center space-y-4">
                    <div className={`p-4 rounded-full bg-white dark:bg-slate-950 shadow-sm ${station.border} border`}>
                      <Icon className={`w-10 h-10 ${station.color}`} />
                    </div>
                    <div>
                      <h2 className="text-xl font-bold">{station.name}</h2>
                      <p className="text-sm font-mono text-slate-500 mt-1">{station.type}</p>
                    </div>
                    <Button variant="ghost" className="opacity-0 group-hover:opacity-100 transition-opacity">
                      Enter Station <ArrowRight className="ml-2 h-4 w-4" />
                    </Button>
                  </CardContent>
                </Card>
              </Link>
            )
          })}
        </div>
      </div>
    </RouteGuard>
  )
}
