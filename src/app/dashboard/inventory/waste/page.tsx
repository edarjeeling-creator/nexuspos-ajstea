'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { ArrowLeft, Trash2 } from 'lucide-react'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import Link from 'next/link'
import { Textarea } from '@/components/ui/textarea'

export default function WasteLogView() {
  return (
    <RouteGuard module="inventory">
      <div className="flex flex-col gap-6 max-w-3xl mx-auto">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Button variant="ghost" size="icon" asChild>
              <Link href="/dashboard/inventory"><ArrowLeft className="h-5 w-5" /></Link>
            </Button>
            <div>
              <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Log Waste</h1>
              <p className="text-slate-500 dark:text-slate-400 mt-1">
                Record spoilage, expired items, or damaged goods.
              </p>
            </div>
          </div>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Waste Details</CardTitle>
            <CardDescription>All waste logs deduct stock immediately and impact COGS.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
             <div className="space-y-2">
               <label className="text-sm font-medium">Inventory Item</label>
               <Select defaultValue="LET-01">
                  <SelectTrigger>
                    <SelectValue placeholder="Select raw material" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="LET-01">Lettuce (Head) - LET-01</SelectItem>
                    <SelectItem value="BUN-001">Burger Buns - BUN-001</SelectItem>
                  </SelectContent>
               </Select>
             </div>
             
             <div className="grid grid-cols-2 gap-4">
               <div className="space-y-2">
                 <label className="text-sm font-medium">Quantity to Deduct</label>
                 <Input type="number" placeholder="0" className="text-lg font-bold text-red-500" />
               </div>
               <div className="space-y-2">
                 <label className="text-sm font-medium">Waste Category</label>
                 <Select defaultValue="SPOILAGE">
                    <SelectTrigger>
                      <SelectValue placeholder="Reason" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="EXPIRED">Expired Date</SelectItem>
                      <SelectItem value="DAMAGED">Damaged in Transit</SelectItem>
                      <SelectItem value="SPOILAGE">Spoiled / Rotten</SelectItem>
                      <SelectItem value="PRODUCTION_WASTE">Production Error / Dropped</SelectItem>
                      <SelectItem value="THEFT">Theft / Unaccounted</SelectItem>
                      <SelectItem value="SAMPLING">Sampling / Quality Check</SelectItem>
                    </SelectContent>
                 </Select>
               </div>
             </div>

             <div className="space-y-2">
               <label className="text-sm font-medium">Manager Notes (Optional)</label>
               <Textarea placeholder="Explain what happened..." className="h-24" />
             </div>

             <Button className="w-full h-12 bg-red-600 hover:bg-red-700 text-white font-bold text-md">
               <Trash2 className="mr-2 h-5 w-5" /> Confirm Waste Deduction
             </Button>
          </CardContent>
        </Card>
      </div>
    </RouteGuard>
  )
}
