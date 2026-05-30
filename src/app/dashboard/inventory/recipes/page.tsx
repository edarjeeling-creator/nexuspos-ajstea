'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { ArrowLeft, Save, Plus, Trash2 } from 'lucide-react'
import { Input } from '@/components/ui/input'
import Link from 'next/link'
import { useState } from 'react'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

export default function RecipeBuilder() {
  const [ingredients, setIngredients] = useState([
    { id: 1, item: 'BUN-001', qty: 1, uom: 'pcs' },
    { id: 2, item: 'PAT-100', qty: 1, uom: 'pcs' },
    { id: 3, item: 'CHZ-02', qty: 1, uom: 'slice' },
    { id: 4, item: 'SAU-99', qty: 10, uom: 'ml' },
  ])

  return (
    <RouteGuard module="inventory">
      <div className="flex flex-col gap-6 max-w-4xl mx-auto">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Button variant="ghost" size="icon" asChild>
              <Link href="/dashboard/inventory"><ArrowLeft className="h-5 w-5" /></Link>
            </Button>
            <div>
              <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Recipe Builder</h1>
              <p className="text-slate-500 dark:text-slate-400 mt-1">
                Map raw materials to menu items for automatic stock deduction.
              </p>
            </div>
          </div>
          <Button className="bg-indigo-600 hover:bg-indigo-700 text-white">
            <Save className="mr-2 h-4 w-4" /> Save Recipe
          </Button>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Finished Good (Menu Item)</CardTitle>
            <CardDescription>Select the product that is sold on the POS.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
             <div className="grid grid-cols-2 gap-4">
               <div className="space-y-2">
                 <label className="text-sm font-medium">Menu Item</label>
                 <Select defaultValue="cheeseburger">
                    <SelectTrigger>
                      <SelectValue placeholder="Select a product" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="cheeseburger">Classic Cheeseburger</SelectItem>
                      <SelectItem value="fries">French Fries (Large)</SelectItem>
                    </SelectContent>
                 </Select>
               </div>
               <div className="space-y-2">
                 <label className="text-sm font-medium">Recipe Yield</label>
                 <Input type="number" defaultValue={1} />
               </div>
             </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <div>
              <CardTitle>Bill of Materials (BOM)</CardTitle>
              <CardDescription>The exact ingredients required to produce 1 yield.</CardDescription>
            </div>
            <Button variant="outline" size="sm" onClick={() => setIngredients([...ingredients, { id: Date.now(), item: '', qty: 0, uom: 'pcs' }])}>
              <Plus className="mr-2 h-4 w-4" /> Add Ingredient
            </Button>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {ingredients.map((ing, idx) => (
                <div key={ing.id} className="flex items-center gap-3 bg-slate-50 dark:bg-slate-900/50 p-2 rounded-md border border-slate-100 dark:border-slate-800">
                  <div className="flex-1">
                    <Select defaultValue={ing.item}>
                      <SelectTrigger className="bg-white dark:bg-slate-950">
                        <SelectValue placeholder="Select raw material" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="BUN-001">Burger Buns (BUN-001)</SelectItem>
                        <SelectItem value="PAT-100">Beef Patties (PAT-100)</SelectItem>
                        <SelectItem value="CHZ-02">Cheddar Cheese (CHZ-02)</SelectItem>
                        <SelectItem value="SAU-99">House Sauce (SAU-99)</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="w-24">
                    <Input type="number" defaultValue={ing.qty} className="bg-white dark:bg-slate-950" />
                  </div>
                  <div className="w-24">
                    <Input type="text" defaultValue={ing.uom} disabled className="bg-slate-100 dark:bg-slate-900" />
                  </div>
                  <Button variant="ghost" size="icon" className="text-red-500 hover:bg-red-50 dark:hover:bg-red-950" onClick={() => setIngredients(ingredients.filter(i => i.id !== ing.id))}>
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              ))}
              
              {ingredients.length === 0 && (
                <div className="text-center py-8 text-slate-500">
                  No ingredients added yet.
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </RouteGuard>
  )
}
