'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Package, AlertCircle, TrendingDown, Layers, FileSpreadsheet, Plus } from 'lucide-react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import Link from 'next/link'

const LOW_STOCK_ITEMS = [
  { id: '1', name: 'Burger Buns', sku: 'BUN-001', stock: 15, reorder: 50, uom: 'pcs' },
  { id: '2', name: 'Beef Patties', sku: 'PAT-100', stock: 8, reorder: 100, uom: 'pcs' },
  { id: '3', name: 'Cooking Oil', sku: 'OIL-05', stock: 2, reorder: 10, uom: 'ltr' },
]

export default function InventoryDashboard() {
  return (
    <RouteGuard module="inventory">
      <div className="flex flex-col gap-6">
        <div className="flex justify-between items-end">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Inventory Core</h1>
            <p className="text-slate-500 dark:text-slate-400 mt-1">
              Real-time stock levels, valuations, and low-stock alerts.
            </p>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" asChild className="h-10">
              <Link href="/dashboard/inventory/recipes"><Package className="mr-2 h-4 w-4" /> Recipe Builder</Link>
            </Button>
            <Button variant="outline" asChild className="h-10">
              <Link href="/dashboard/inventory/ledger"><FileSpreadsheet className="mr-2 h-4 w-4" /> Stock Ledger</Link>
            </Button>
            <Button className="h-10 bg-indigo-600 hover:bg-indigo-700 text-white">
              <Plus className="mr-2 h-4 w-4" /> Add Item
            </Button>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Stock Value</CardTitle>
              <Layers className="h-4 w-4 text-indigo-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">$14,230.50</div>
              <p className="text-xs text-slate-500">Across all warehouses</p>
            </CardContent>
          </Card>
          
          <Card className="border-red-200 dark:border-red-900/50 bg-red-50/30 dark:bg-red-950/20">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-red-600 dark:text-red-400">Low Stock Alerts</CardTitle>
              <AlertCircle className="h-4 w-4 text-red-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-red-600 dark:text-red-400">3</div>
              <p className="text-xs text-red-500/80">Items below reorder level</p>
            </CardContent>
          </Card>
          
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Active Recipes</CardTitle>
              <Package className="h-4 w-4 text-slate-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">42</div>
              <p className="text-xs text-slate-500">Menu items mapped</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Consumption</CardTitle>
              <TrendingDown className="h-4 w-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">$845.20</div>
              <p className="text-xs text-slate-500">COGS Today</p>
            </CardContent>
          </Card>
        </div>

        <div className="grid gap-4 lg:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle className="text-red-600 flex items-center gap-2">
                <AlertCircle className="h-5 w-5" /> Requires Purchasing
              </CardTitle>
              <CardDescription>Items that have breached their minimum reorder thresholds.</CardDescription>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>SKU</TableHead>
                    <TableHead>Item Name</TableHead>
                    <TableHead className="text-right">Current Stock</TableHead>
                    <TableHead className="text-right">Reorder Lvl</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {LOW_STOCK_ITEMS.map(item => (
                    <TableRow key={item.id}>
                      <TableCell className="font-mono text-xs">{item.sku}</TableCell>
                      <TableCell className="font-medium">{item.name}</TableCell>
                      <TableCell className="text-right font-bold text-red-500">{item.stock} {item.uom}</TableCell>
                      <TableCell className="text-right text-slate-500">{item.reorder} {item.uom}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
              <Button className="w-full mt-4 bg-indigo-600 hover:bg-indigo-700 text-white">Generate Purchase Order</Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </RouteGuard>
  )
}
