import { getCategories, createCategory, deleteCategory } from './actions'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Plus, Trash2 } from 'lucide-react'

export default async function CategoriesPage() {
  const categories = await getCategories()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Categories</h1>
          <p className="text-slate-500 dark:text-slate-400 mt-1">
            Manage hierarchical categories for inventory and menu items.
          </p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-3">
        {/* Create Form */}
        <Card className="md:col-span-1 h-fit">
          <CardHeader>
            <CardTitle>Add Category</CardTitle>
            <CardDescription>Create a new category for your items.</CardDescription>
          </CardHeader>
          <CardContent>
            <form action={createCategory} className="space-y-4">
              <div>
                <label htmlFor="name" className="block text-sm font-medium mb-1">Name</label>
                <input 
                  id="name" 
                  name="name" 
                  required 
                  className="w-full px-3 py-2 border rounded-md dark:bg-slate-900 dark:border-slate-800"
                  placeholder="e.g. Beverages"
                />
              </div>
              <Button type="submit" className="w-full">
                <Plus className="mr-2 h-4 w-4" /> Create Category
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* List */}
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>All Categories</CardTitle>
          </CardHeader>
          <CardContent>
            {categories.length === 0 ? (
              <div className="text-center py-12 text-slate-500">
                No categories found. Create your first one!
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {categories.map((cat: any) => (
                    <TableRow key={cat.id}>
                      <TableCell className="font-medium">{cat.name}</TableCell>
                      <TableCell>
                        <span className={`px-2 py-1 text-xs rounded-full ${cat.status === 'ACTIVE' ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-slate-100 text-slate-700'}`}>
                          {cat.status}
                        </span>
                      </TableCell>
                      <TableCell className="text-right">
                        <form action={async () => {
                          'use server';
                          await deleteCategory(cat.id);
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
