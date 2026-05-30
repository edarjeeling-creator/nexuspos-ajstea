'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Printer, Clock, FileText, CheckCircle2, AlertTriangle, ArrowRight } from 'lucide-react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

const MOCK_SHIFTS = [
  { id: '1', register: 'Terminal 1', openedAt: '08:00 AM', closedAt: '04:00 PM', cashier: 'John Doe', status: 'CLOSED', expected: 1250.00, actual: 1250.00, variance: 0 },
  { id: '2', register: 'Terminal 2', openedAt: '09:00 AM', closedAt: '05:30 PM', cashier: 'Jane Smith', status: 'CLOSED', expected: 840.50, actual: 835.50, variance: -5.00 },
  { id: '3', register: 'Terminal 1', openedAt: '04:15 PM', closedAt: null, cashier: 'Mike Johnson', status: 'OPEN', expected: null, actual: null, variance: null },
]

export default function ShiftDashboard() {
  return (
    <RouteGuard module="shift">
      <div className="flex flex-col gap-6">
        <div className="flex justify-between items-end">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Shift Management</h1>
            <p className="text-slate-500 dark:text-slate-400 mt-1">
              Monitor active tills, historical shifts, and end-of-day reports.
            </p>
          </div>
          <Button variant="outline">
            <Printer className="mr-2 h-4 w-4" /> Print Summary
          </Button>
        </div>

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Open Shifts</CardTitle>
              <Clock className="h-4 w-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">1</div>
              <p className="text-xs text-slate-500">Currently active on floor</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Net Variance (Today)</CardTitle>
              <AlertTriangle className="h-4 w-4 text-amber-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-red-500">-$5.00</div>
              <p className="text-xs text-slate-500">Across 2 closed shifts</p>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Shift Timeline</CardTitle>
            <CardDescription>Recent register activity across the outlet.</CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Status</TableHead>
                  <TableHead>Register</TableHead>
                  <TableHead>Cashier</TableHead>
                  <TableHead>Opened</TableHead>
                  <TableHead>Closed</TableHead>
                  <TableHead className="text-right">Variance</TableHead>
                  <TableHead></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {MOCK_SHIFTS.map(shift => (
                  <TableRow key={shift.id}>
                    <TableCell>
                      {shift.status === 'OPEN' ? (
                         <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400">
                           <span className="h-1.5 w-1.5 rounded-full bg-blue-500 animate-pulse"></span> Open
                         </span>
                      ) : (
                         <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-400">
                           <CheckCircle2 className="h-3 w-3" /> Closed
                         </span>
                      )}
                    </TableCell>
                    <TableCell className="font-medium">{shift.register}</TableCell>
                    <TableCell>{shift.cashier}</TableCell>
                    <TableCell>{shift.openedAt}</TableCell>
                    <TableCell>{shift.closedAt || '-'}</TableCell>
                    <TableCell className="text-right">
                      {shift.variance !== null ? (
                        <span className={shift.variance === 0 ? 'text-green-600' : 'text-red-500 font-medium'}>
                          {shift.variance === 0 ? '$0.00' : `${shift.variance > 0 ? '+' : ''}$${shift.variance.toFixed(2)}`}
                        </span>
                      ) : (
                        <span className="text-slate-400">-</span>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm" className="h-8">
                        <FileText className="h-4 w-4 mr-2" /> Z-Report
                      </Button>
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
