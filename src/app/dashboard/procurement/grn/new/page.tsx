'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { ArrowLeft, CheckCircle2, Box } from 'lucide-react'
import { Input } from '@/components/ui/input'
import Link from 'next/link'
import { useState } from 'react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

export default function PostGRNView() {
  const [items, setItems] = useState([
    { id: 1, item: 'Beef Patties', sku: 'PAT-100', ordered: 1000, received: 1000, batch: 'BCH-052026', expiry: '2026-06-15' },
    { id: 2, item: 'Burger Buns', sku: 'BUN-001', ordered: 500, received: 480, batch: 'BUN-X8', expiry: '2026-06-05' },
  ])

  const handleReceivedChange = (id: number, val: string) => {
    setItems(items.map(item => item.id === id ? { ...item, received: parseInt(val) || 0 } : item))
  }

  const handleBatchChange = (id: number, val: string) => {
    setItems(items.map(item => item.id === id ? { ...item, batch: val } : item))
  }

  const handleExpiryChange = (id: number, val: string) => {
    setItems(items.map(item => item.id === id ? { ...item, expiry: val } : item))
  }

  return (
    <RouteGuard module="inventory">
      <div className="flex flex-col gap-6 max-w-5xl mx-auto">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Button variant="ghost" size="icon" asChild>
              <Link href="/dashboard/procurement"><ArrowLeft className="h-5 w-5" /></Link>
            </Button>
            <div>
              <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Post GRN</h1>
              <p className="text-slate-500 dark:text-slate-400 mt-1">
                Receive goods against PO-2026-002 (Global Meats Ltd)
              </p>
            </div>
          </div>
          <Button className="bg-green-600 hover:bg-green-700 text-white">
            <CheckCircle2 className="mr-2 h-4 w-4" /> Confirm & Post to Ledger
          </Button>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Receiving Details</CardTitle>
            <CardDescription>Enter the quantities actually received on the dock.</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="border rounded-lg overflow-hidden dark:border-slate-800">
              <Table>
                <TableHeader className="bg-slate-50 dark:bg-slate-900">
                  <TableRow>
                    <TableHead>Item</TableHead>
                    <TableHead className="text-right">Ordered</TableHead>
                    <TableHead className="text-right w-32">Received</TableHead>
                    <TableHead>Batch #</TableHead>
                    <TableHead>Expiry Date</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {items.map(item => (
                    <TableRow key={item.id}>
                      <TableCell>
                        <div className="font-medium">{item.item}</div>
                        <div className="text-xs font-mono text-slate-500">{item.sku}</div>
                      </TableCell>
                      <TableCell className="text-right font-medium">{item.ordered}</TableCell>
                      <TableCell className="text-right">
                        <Input 
                          type="number" 
                          value={item.received} 
                          onChange={(e) => handleReceivedChange(item.id, e.target.value)}
                          className={`text-right font-bold ${item.received < item.ordered ? 'border-amber-400 text-amber-600' : ''}`}
                        />
                      </TableCell>
                      <TableCell>
                         <Input 
                          type="text" 
                          value={item.batch} 
                          onChange={(e) => handleBatchChange(item.id, e.target.value)}
                          placeholder="Lot/Batch"
                        />
                      </TableCell>
                      <TableCell>
                         <Input 
                          type="date" 
                          value={item.expiry} 
                          onChange={(e) => handleExpiryChange(item.id, e.target.value)}
                        />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </CardContent>
          <CardFooter className="bg-slate-50 dark:bg-slate-900/50 border-t dark:border-slate-800 py-4">
             <div className="flex items-center gap-3 text-sm text-slate-500">
               <Box className="h-5 w-5" />
               Posting this GRN will automatically increase stock in the inventory_transactions ledger. Direct manual stock increases are disabled for items tied to POs.
             </div>
          </CardFooter>
        </Card>
      </div>
    </RouteGuard>
  )
}
