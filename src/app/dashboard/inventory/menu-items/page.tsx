import { getMenuItems, createMenuItem, deleteMenuItem } from './actions'
import { getCategories } from '../raw-materials/actions' // Reusing category fetcher
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Plus, Trash2 } from 'lucide-react'

export default async function MenuItemsPage() {
  const menuItems = await getMenuItems()
  const categories = await getCategories()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Menu Items</h1>
          <p className="text-slate-500 dark:text-slate-400 mt-1">
            Manage the catalog of products that you sell on the POS.
          </p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-3">
        {/* Create Form */}
        <Card className="md:col-span-1 h-fit">
          <CardHeader>
            <CardTitle>Add Menu Item</CardTitle>
            <CardDescription>Create a new product for sale.</CardDescription>
          </CardHeader>
          <CardContent>
            <form action={createMenuItem} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">Name</label>
                <input name="name" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="e.g. Margherita Pizza" />
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-sm font-medium mb-1">Item Code</label>
                  <input name="item_code" className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="PZA-MARG" />
                </div>
                <div>
                  <label className="block text-sm font-medium mb-1">Price ($)</label>
                  <input name="price" type="number" step="0.01" min="0" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="0.00" />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Category</label>
                <select name="category_id" className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800">
                  <option value="null">-- No Category --</option>
                  {categories.map((c: any) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Type</label>
                <select name="menu_type" className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800">
                  <option value="FOOD">Food</option>
                  <option value="BEVERAGE">Beverage</option>
                  <option value="ALCOHOL">Alcohol</option>
                  <option value="RETAIL">Retail</option>
                </select>
              </div>
              <Button type="submit" className="w-full bg-indigo-600 hover:bg-indigo-700 text-white">
                <Plus className="mr-2 h-4 w-4" /> Add Menu Item
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* List */}
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>POS Catalog</CardTitle>
          </CardHeader>
          <CardContent>
            {menuItems.length === 0 ? (
              <div className="text-center py-12 text-slate-500">
                No menu items found.
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Code</TableHead>
                    <TableHead>Name</TableHead>
                    <TableHead>Category</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead className="text-right">Price</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {menuItems.map((item: any) => (
                    <TableRow key={item.id}>
                      <TableCell className="font-mono text-xs">{item.item_code || '-'}</TableCell>
                      <TableCell className="font-medium">{item.name}</TableCell>
                      <TableCell className="text-slate-500">{item.category?.name || '-'}</TableCell>
                      <TableCell>{item.menu_type}</TableCell>
                      <TableCell className="text-right font-bold text-indigo-600 dark:text-indigo-400">
                        ${item.price?.toFixed(2)}
                      </TableCell>
                      <TableCell className="text-right">
                        <form action={async () => {
                          'use server';
                          await deleteMenuItem(item.id);
                        }}>
                          <Button variant="ghost" size="sm" type="submit" className="text-red-500 hover:text-red-700 hover:bg-red-50 dark:hover:bg-red-950/50">
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </form>
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
