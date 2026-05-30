'use client'

import { RouteGuard } from '@/components/auth/route-guard'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { ArrowLeft, Star, TrendingUp, TrendingDown, Clock, ShieldCheck, DollarSign } from 'lucide-react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import Link from 'next/link'

const SCORECARDS = [
  { id: '1', supplier: 'Fresh Foods Co.', onTime: 4.8, quality: 4.5, pricing: 4.0, overall: 4.43, trend: 'up' },
  { id: '2', supplier: 'Global Meats Ltd', onTime: 3.2, quality: 4.9, pricing: 3.5, overall: 3.86, trend: 'down' },
  { id: '3', supplier: 'City Bakery', onTime: 5.0, quality: 5.0, pricing: 4.8, overall: 4.93, trend: 'up' },
]

export default function SupplierScorecards() {
  return (
    <RouteGuard module="inventory">
      <div className="flex flex-col gap-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/procurement"><ArrowLeft className="h-5 w-5" /></Link>
          </Button>
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Supplier Scorecards</h1>
            <p className="text-slate-500 dark:text-slate-400 mt-1">
              Evaluate vendor performance based on GRN data and quality checks.
            </p>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-3">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Top Performer</CardTitle>
              <Star className="h-4 w-4 text-amber-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">City Bakery</div>
              <p className="text-xs text-slate-500">4.93 / 5.00 Overall Rating</p>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Performance Matrix</CardTitle>
            <CardDescription>Metrics are calculated automatically from PO delivery dates and GRN quality inspections.</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="border rounded-lg overflow-hidden dark:border-slate-800">
              <Table>
                <TableHeader className="bg-slate-50 dark:bg-slate-900">
                  <TableRow>
                    <TableHead>Supplier</TableHead>
                    <TableHead className="text-center">On-Time Delivery</TableHead>
                    <TableHead className="text-center">Quality / Spoilage</TableHead>
                    <TableHead className="text-center">Pricing Competitiveness</TableHead>
                    <TableHead className="text-right">Overall Score</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {SCORECARDS.map(score => (
                    <TableRow key={score.id}>
                      <TableCell className="font-medium">{score.supplier}</TableCell>
                      <TableCell className="text-center">
                        <div className="flex items-center justify-center gap-2">
                          <Clock className={`h-4 w-4 ${score.onTime > 4 ? 'text-green-500' : 'text-amber-500'}`} />
                          {score.onTime.toFixed(1)}
                        </div>
                      </TableCell>
                      <TableCell className="text-center">
                        <div className="flex items-center justify-center gap-2">
                          <ShieldCheck className={`h-4 w-4 ${score.quality > 4 ? 'text-green-500' : 'text-amber-500'}`} />
                          {score.quality.toFixed(1)}
                        </div>
                      </TableCell>
                      <TableCell className="text-center">
                        <div className="flex items-center justify-center gap-2">
                          <DollarSign className={`h-4 w-4 ${score.pricing > 4 ? 'text-green-500' : 'text-amber-500'}`} />
                          {score.pricing.toFixed(1)}
                        </div>
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex items-center justify-end gap-2 font-bold text-lg">
                          {score.overall.toFixed(2)}
                          {score.trend === 'up' ? <TrendingUp className="h-4 w-4 text-green-500" /> : <TrendingDown className="h-4 w-4 text-red-500" />}
                        </div>
                      </TableCell>
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
