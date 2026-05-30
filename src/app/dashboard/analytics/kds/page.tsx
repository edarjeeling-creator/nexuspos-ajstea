'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Activity, Clock, Flame, CheckCircle, AlertOctagon } from 'lucide-react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

const METRICS = [
  { station: 'Grill', avgPrepTime: '8m 45s', throughput: '142', slaBreach: '4%', status: 'OPTIMAL' },
  { station: 'Bar', avgPrepTime: '2m 10s', throughput: '210', slaBreach: '1%', status: 'OPTIMAL' },
  { station: 'Fryer', avgPrepTime: '12m 30s', throughput: '98', slaBreach: '18%', status: 'BOTTLENECK' },
]

export default function KDSAnalytics() {
  return (
    <RouteGuard module="analytics">
      <div className="flex flex-col gap-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">KDS Performance</h1>
          <p className="text-slate-500 dark:text-slate-400 mt-1">
            Real-time analytics on kitchen throughput, prep times, and SLA breaches.
          </p>
        </div>

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Avg Prep Time (Global)</CardTitle>
              <Clock className="h-4 w-4 text-indigo-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">6m 12s</div>
              <p className="text-xs text-green-500">-30s from last week</p>
            </CardContent>
          </Card>
          
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Tickets Served (Today)</CardTitle>
              <CheckCircle className="h-4 w-4 text-green-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">450</div>
              <p className="text-xs text-slate-500">Across all stations</p>
            </CardContent>
          </Card>

          <Card className="border-red-200 dark:border-red-900/50 bg-red-50/30 dark:bg-red-950/20">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-red-600 dark:text-red-400">SLA Breaches (>15m)</CardTitle>
              <AlertOctagon className="h-4 w-4 text-red-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-red-600 dark:text-red-400">22</div>
              <p className="text-xs text-red-500/80">Tickets took too long</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Current Bottleneck</CardTitle>
              <Flame className="h-4 w-4 text-orange-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-orange-600">Fryer</div>
              <p className="text-xs text-slate-500">Highest queue depth</p>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Station Utilization & Throughput</CardTitle>
            <CardDescription>Metrics are fed to AI forecasting engines to optimize staffing models.</CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Station</TableHead>
                  <TableHead>Throughput (Today)</TableHead>
                  <TableHead>Avg Prep Time</TableHead>
                  <TableHead>SLA Breach Rate</TableHead>
                  <TableHead className="text-right">Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {METRICS.map((m, i) => (
                  <TableRow key={i}>
                    <TableCell className="font-bold">{m.station}</TableCell>
                    <TableCell className="font-mono">{m.throughput}</TableCell>
                    <TableCell className="font-mono">{m.avgPrepTime}</TableCell>
                    <TableCell className={`font-mono ${m.slaBreach === '18%' ? 'text-red-500 font-bold' : ''}`}>{m.slaBreach}</TableCell>
                    <TableCell className="text-right">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold
                        ${m.status === 'OPTIMAL' ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : ''}
                        ${m.status === 'BOTTLENECK' ? 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400' : ''}
                      `}>
                        {m.status}
                      </span>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>
    </RouteGuard>
  )
}
