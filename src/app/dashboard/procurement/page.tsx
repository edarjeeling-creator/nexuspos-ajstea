'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { ArrowRight, Truck, FileCheck, Star, AlertTriangle, TrendingUp } from 'lucide-react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import Link from 'next/link'

const MOCK_POS = [
  { id: '1', po: 'PO-2026-001', supplier: 'Fresh Foods Co.', amount: 1250.00, status: 'PENDING', date: '2026-05-30' },
  { id: '2', po: 'PO-2026-002', supplier: 'Global Meats Ltd', amount: 4800.50, status: 'ISSUED', date: '2026-05-31' },
  { id: '3', po: 'PO-2026-003', supplier: 'City Bakery', amount: 320.00, status: 'OVERDUE', date: '2026-05-28' },
]

export default function ProcurementDashboard() {
  return (
    <RouteGuard module="inventory">
      <div className="flex flex-col gap-6">
        <div className="flex justify-between items-end">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Procurement & ERP</h1>
            <p className="text-slate-500 dark:text-slate-400 mt-1">
              Manage suppliers, purchase orders, and Goods Receipt Notes (GRN).
            </p>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" asChild className="h-10">
              <Link href="/dashboard/procurement/suppliers"><Star className="mr-2 h-4 w-4" /> Suppliers</Link>
            </Button>
            <Button className="h-10 bg-indigo-600 hover:bg-indigo-700 text-white">
              Create PO
            </Button>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Pending Approvals</CardTitle>
              <FileCheck className="h-4 w-4 text-indigo-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">4</div>
              <p className="text-xs text-slate-500">Purchase orders awaiting review</p>
            </CardContent>
          </Card>
          
          <Card className="border-red-200 dark:border-red-900/50 bg-red-50/30 dark:bg-red-950/20">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-red-600 dark:text-red-400">Overdue Deliveries</CardTitle>
              <AlertTriangle className="h-4 w-4 text-red-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-red-600 dark:text-red-400">1</div>
              <p className="text-xs text-red-500/80">Require immediate follow-up</p>
            </CardContent>
          </Card>
          
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Expected Deliveries</CardTitle>
              <Truck className="h-4 w-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">12</div>
              <p className="text-xs text-slate-500">Arriving in next 7 days</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Avg Supplier Rating</CardTitle>
              <TrendingUp className="h-4 w-4 text-green-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">4.6<span className="text-sm text-slate-500">/5</span></div>
              <p className="text-xs text-slate-500">Based on recent scorecards</p>
            </CardContent>
          </Card>
        </div>

        <div className="grid gap-4 lg:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>Active Purchase Orders</CardTitle>
              <CardDescription>Track status of outbound orders to suppliers.</CardDescription>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>PO Number</TableHead>
                    <TableHead>Supplier</TableHead>
                    <TableHead>Expected</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Amount</TableHead>
                    <TableHead></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {MOCK_POS.map(po => (
                    <TableRow key={po.id}>
                      <TableCell className="font-mono text-xs">{po.po}</TableCell>
                      <TableCell className="font-medium">{po.supplier}</TableCell>
                      <TableCell className="text-slate-500">{po.date}</TableCell>
                      <TableCell>
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold
                          ${po.status === 'PENDING' ? 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400' : ''}
                          ${po.status === 'ISSUED' ? 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' : ''}
                          ${po.status === 'OVERDUE' ? 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400' : ''}
                        `}>
                          {po.status}
                        </span>
                      </TableCell>
                      <TableCell className="text-right font-bold">${po.amount.toFixed(2)}</TableCell>
                      <TableCell className="text-right">
                        {po.status === 'ISSUED' || po.status === 'OVERDUE' ? (
                           <Button variant="ghost" size="sm" asChild>
                             <Link href={`/dashboard/procurement/grn/new?po=${po.po}`}>Post GRN <ArrowRight className="ml-2 h-4 w-4" /></Link>
                           </Button>
                        ) : (
                           <Button variant="ghost" size="sm">Review</Button>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </div>
      </div>
    </RouteGuard>
  )
}
