import { seedInventoryData } from './actions'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Database, AlertTriangle } from 'lucide-react'

export default function InventorySettingsPage() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">Inventory Settings</h1>
          <p className="text-slate-500 dark:text-slate-400 mt-1">
            System configuration and advanced data tools.
          </p>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card className="border-orange-200 bg-orange-50/50 dark:border-orange-900/50 dark:bg-orange-950/20">
          <CardHeader>
            <CardTitle className="text-orange-700 dark:text-orange-400 flex items-center gap-2">
              <Database className="h-5 w-5" /> Load Demo Data
            </CardTitle>
            <CardDescription className="text-orange-600/80 dark:text-orange-400/80">
              Generate a realistic set of categories, raw materials, menu items, recipes, and initial stock levels for a Cafe/Tea Shop.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex p-4 mb-4 text-sm text-orange-800 rounded-lg bg-orange-100 dark:bg-orange-900/30 dark:text-orange-300">
              <AlertTriangle className="flex-shrink-0 inline w-4 h-4 me-3 mt-[2px]" />
              <div>
                <span className="font-medium">Warning!</span> This will insert new records into your tenant. It will not delete existing data, but it may cause duplicates if run multiple times.
              </div>
            </div>
            <form action={seedInventoryData}>
              <Button type="submit" className="w-full bg-orange-600 hover:bg-orange-700 text-white">
                Seed Cafe & Tea Shop Data
              </Button>
            </form>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
