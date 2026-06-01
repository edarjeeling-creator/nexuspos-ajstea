import { getStockLevels, getWarehouses, addStockAdjustment } from './actions'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Plus } from 'lucide-react'

export default async function StockTrackingPage() {
  const stockLevels = await getStockLevels()
  const warehouses = await getWarehouses()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Stock Tracking</h1>
          <p className="text-slate-500 dark:text-slate-400 mt-1">
            View current stock levels and record adjustments.
          </p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-3">
        {/* Record Transaction Form */}
        <Card className="md:col-span-1 h-fit">
          <CardHeader>
            <CardTitle>Adjust Stock</CardTitle>
            <CardDescription>Record a manual inventory transaction.</CardDescription>
          </CardHeader>
          <CardContent>
            <form action={addStockAdjustment} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">Item</label>
                <select name="inventory_item_id" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800">
                  <option value="">-- Select Item --</option>
                  {stockLevels.map((item: any) => (
                    <option key={item.id} value={item.id}>{item.name} ({item.sku})</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Transaction Type</label>
                <select name="transaction_type" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800">
                  <option value="PURCHASE">Purchase (+)</option>
                  <option value="ADJUSTMENT">Adjustment (+/-)</option>
                  <option value="WASTE">Waste (-)</option>
                </select>
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-sm font-medium mb-1">Quantity</label>
                  <input name="quantity_change" type="number" step="0.001" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="0" />
                </div>
                <div>
                  <label className="block text-sm font-medium mb-1">Unit Cost ($)</label>
                  <input name="unit_cost" type="number" step="0.01" min="0" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="0.00" />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Warehouse</label>
                <select name="warehouse_id" className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800">
                  <option value="null">-- Default Location --</option>
                  {warehouses.map((w: any) => (
                    <option key={w.id} value={w.id}>{w.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Notes</label>
                <textarea name="notes" rows={2} className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="Reason for adjustment"></textarea>
              </div>
              <Button type="submit" className="w-full bg-indigo-600 hover:bg-indigo-700 text-white">
                <Plus className="mr-2 h-4 w-4" /> Record Transaction
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Current Stock Levels */}
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>Current Stock Levels</CardTitle>
          </CardHeader>
          <CardContent>
            {stockLevels.length === 0 ? (
              <div className="text-center py-12 text-slate-500">
                No items found. Add raw materials first.
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>SKU</TableHead>
                    <TableHead>Name</TableHead>
                    <TableHead className="text-right">Unit Value</TableHead>
                    <TableHead className="text-right">Total Stock</TableHead>
                    <TableHead className="text-right">Total Value</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {stockLevels.map((item: any) => (
                    <TableRow key={item.id}>
                      <TableCell className="font-mono text-xs">{item.sku}</TableCell>
                      <TableCell className="font-medium">{item.name}</TableCell>
                      <TableCell className="text-right">${item.cost_price?.toFixed(2)}</TableCell>
                      <TableCell className="text-right font-bold">
                        <span className={item.current_stock < 0 ? 'text-red-500' : 'text-slate-900 dark:text-white'}>
                          {item.current_stock.toFixed(2)} {item.unit_of_measure}
                        </span>
                      </TableCell>
                      <TableCell className="text-right text-indigo-600 dark:text-indigo-400">
                        ${(item.current_stock * item.cost_price).toFixed(2)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
