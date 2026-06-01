import { getRawMaterials, getCategories, createRawMaterial, deleteRawMaterial } from './actions'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Plus, Trash2 } from 'lucide-react'

export default async function RawMaterialsPage() {
  const materials = await getRawMaterials()
  const categories = await getCategories()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Raw Materials</h1>
          <p className="text-slate-500 dark:text-slate-400 mt-1">
            Manage ingredients, supplies, and raw items purchased for inventory.
          </p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-3">
        {/* Create Form */}
        <Card className="md:col-span-1 h-fit">
          <CardHeader>
            <CardTitle>Add Material</CardTitle>
            <CardDescription>Register a new raw material.</CardDescription>
          </CardHeader>
          <CardContent>
            <form action={createRawMaterial} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">Name</label>
                <input name="name" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="e.g. Flour" />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">SKU</label>
                <input name="sku" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="FLR-001" />
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
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-sm font-medium mb-1">Unit of Measure</label>
                  <input name="unit_of_measure" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="kg, L, pcs" />
                </div>
                <div>
                  <label className="block text-sm font-medium mb-1">Cost Price ($)</label>
                  <input name="cost_price" type="number" step="0.01" min="0" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="0.00" />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Reorder Level</label>
                <input name="reorder_level" type="number" step="0.01" min="0" required className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800" placeholder="10" />
              </div>
              <Button type="submit" className="w-full">
                <Plus className="mr-2 h-4 w-4" /> Add Material
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* List */}
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>Material Catalog</CardTitle>
          </CardHeader>
          <CardContent>
            {materials.length === 0 ? (
              <div className="text-center py-12 text-slate-500">
                No raw materials found.
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>SKU</TableHead>
                    <TableHead>Name</TableHead>
                    <TableHead>Category</TableHead>
                    <TableHead>UoM</TableHead>
                    <TableHead className="text-right">Cost</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {materials.map((item: any) => (
                    <TableRow key={item.id}>
                      <TableCell className="font-mono text-xs">{item.sku}</TableCell>
                      <TableCell className="font-medium">{item.name}</TableCell>
                      <TableCell className="text-slate-500">{item.category?.name || '-'}</TableCell>
                      <TableCell>{item.unit_of_measure}</TableCell>
                      <TableCell className="text-right">${item.cost_price?.toFixed(2)}</TableCell>
                      <TableCell className="text-right">
                        <form action={async () => {
                          'use server';
                          await deleteRawMaterial(item.id);
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
