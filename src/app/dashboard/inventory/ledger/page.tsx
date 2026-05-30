'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { ArrowLeft, Search, Filter } from 'lucide-react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Input } from '@/components/ui/input'
import Link from 'next/link'

const MOCK_LEDGER = [
  { id: '1', date: '2026-05-29 18:05:22', type: 'SALE', item: 'Burger Buns', sku: 'BUN-001', change: -2.0, cost: 0.00, ref: 'ORDER: a1b2c3d4' },
  { id: '2', date: '2026-05-29 18:05:22', type: 'SALE', item: 'Beef Patties', sku: 'PAT-100', change: -2.0, cost: 0.00, ref: 'ORDER: a1b2c3d4' },
  { id: '3', date: '2026-05-29 17:30:00', type: 'SALE', item: 'Cooking Oil', sku: 'OIL-05', change: -0.5, cost: 0.00, ref: 'ORDER: e5f6g7h8' },
  { id: '4', date: '2026-05-29 09:00:00', type: 'PURCHASE', item: 'Burger Buns', sku: 'BUN-001', change: +50.0, cost: 0.25, ref: 'PO: 998877' },
  { id: '5', date: '2026-05-29 09:00:00', type: 'PURCHASE', item: 'Beef Patties', sku: 'PAT-100', change: +100.0, cost: 1.50, ref: 'PO: 998877' },
  { id: '6', date: '2026-05-28 22:00:00', type: 'WASTE', item: 'Lettuce (Head)', sku: 'LET-01', change: -1.0, cost: 0.00, ref: 'MANUAL_ADJUSTMENT' },
]

export default function StockLedgerView() {
  return (
    <RouteGuard module="inventory">
      <div className="flex flex-col gap-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/inventory"><ArrowLeft className="h-5 w-5" /></Link>
          </Button>
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Stock Ledger</h1>
            <p className="text-slate-500 dark:text-slate-400 mt-1">
              Immutable history of all physical stock movements.
            </p>
          </div>
        </div>

        <Card>
          <CardHeader className="flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
            <div>
              <CardTitle>Transaction History</CardTitle>
              <CardDescription>View every stock insertion and deduction across the system.</CardDescription>
            </div>
            <div className="flex gap-2 w-full sm:w-auto">
              <div className="relative w-full sm:w-64">
                <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-slate-500" />
                <Input type="text" placeholder="Search SKU or Item..." className="pl-9" />
              </div>
              <Button variant="outline" size="icon">
                <Filter className="h-4 w-4" />
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <div className="border rounded-lg overflow-hidden dark:border-slate-800">
              <Table>
                <TableHeader className="bg-slate-50 dark:bg-slate-900">
                  <TableRow>
                    <TableHead>Timestamp</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Item</TableHead>
                    <TableHead>SKU</TableHead>
                    <TableHead className="text-right">Qty Change</TableHead>
                    <TableHead className="text-right">Unit Cost</TableHead>
                    <TableHead>Reference</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {MOCK_LEDGER.map(tx => (
                    <TableRow key={tx.id}>
                      <TableCell className="text-xs text-slate-500">{tx.date}</TableCell>
                      <TableCell>
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold
                          ${tx.type === 'SALE' ? 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' : ''}
                          ${tx.type === 'PURCHASE' ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : ''}
                          ${tx.type === 'WASTE' ? 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400' : ''}
                        `}>
                          {tx.type}
                        </span>
                      </TableCell>
                      <TableCell className="font-medium">{tx.item}</TableCell>
                      <TableCell className="font-mono text-xs">{tx.sku}</TableCell>
                      <TableCell className={`text-right font-bold ${tx.change > 0 ? 'text-green-600' : 'text-red-500'}`}>
                        {tx.change > 0 ? '+' : ''}{tx.change.toFixed(2)}
                      </TableCell>
                      <TableCell className="text-right">${tx.cost.toFixed(2)}</TableCell>
                      <TableCell className="font-mono text-xs text-slate-500">{tx.ref}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </div>
    </RouteGuard>
  )
}
