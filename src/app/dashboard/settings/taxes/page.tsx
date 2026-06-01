'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/utils/supabase/client'
import { useTenant } from '@/hooks/useTenant'
import { Button } from '@/components/ui/button'

export default function TaxSettingsPage() {
  const supabase = createClient()
  const { outletId, isLoading: tenantLoading } = useTenant()
  const [isLoading, setIsLoading] = useState(false)

  const [formData, setFormData] = useState({
    global_tax_rate: 0,
    apply_dine_in: true,
    apply_takeaway: false,
    apply_delivery: false,
    print_gstin: true
  })

  useEffect(() => {
    if (!outletId) return

    async function fetchSettings() {
      const { data } = await supabase
        .from('outlets')
        .select('settings')
        .eq('id', outletId)
        .single()

      if (data && data.settings) {
        setFormData({
          global_tax_rate: data.settings.global_tax_rate || 0,
          apply_dine_in: data.settings.apply_dine_in !== undefined ? data.settings.apply_dine_in : true,
          apply_takeaway: data.settings.apply_takeaway || false,
          apply_delivery: data.settings.apply_delivery || false,
          print_gstin: data.settings.print_gstin !== undefined ? data.settings.print_gstin : true,
        })
      }
    }
    fetchSettings()
  }, [outletId, supabase])

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.type === 'checkbox' ? e.target.checked : Number(e.target.value)
    setFormData((prev) => ({ ...prev, [e.target.name]: value }))
  }

  const handleSave = async () => {
    if (!outletId) return
    setIsLoading(true)

    const { data: currentData } = await supabase
      .from('outlets')
      .select('settings')
      .eq('id', outletId)
      .single()

    const currentSettings = currentData?.settings || {}
    const newSettings = {
      ...currentSettings,
      global_tax_rate: formData.global_tax_rate,
      apply_dine_in: formData.apply_dine_in,
      apply_takeaway: formData.apply_takeaway,
      apply_delivery: formData.apply_delivery,
      print_gstin: formData.print_gstin
    }

    const { error } = await supabase
      .from('outlets')
      .update({ settings: newSettings })
      .eq('id', outletId)

    setIsLoading(false)
    if (!error) {
      alert('Tax settings saved successfully!')
    } else {
      alert('Failed to save settings: ' + error.message)
    }
  }

  if (tenantLoading) return <div>Loading...</div>

  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <h3 className="text-lg font-medium leading-6 text-slate-900 dark:text-white">Tax Configuration</h3>
        <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
          Manage how taxes are applied to orders and printed on receipts.
        </p>
      </div>

      <div className="space-y-6">
        <div>
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Global Default Tax Rate (%)</label>
          <div className="mt-1">
            <input type="number" step="0.01" name="global_tax_rate" value={formData.global_tax_rate} onChange={handleChange}
              className="block w-full max-w-xs rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
          </div>
          <p className="mt-1 text-xs text-slate-500">This rate applies to all items unless overridden on the specific item.</p>
        </div>

        <div className="border-t border-slate-200 dark:border-slate-800 pt-6">
          <h4 className="text-sm font-medium text-slate-900 dark:text-white mb-4">Apply Tax to Order Types</h4>
          <div className="space-y-4">
            <div className="flex items-center">
              <input id="apply_dine_in" name="apply_dine_in" type="checkbox" checked={formData.apply_dine_in} onChange={handleChange}
                className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
              <label htmlFor="apply_dine_in" className="ml-2 block text-sm text-slate-900 dark:text-slate-300">
                Dine-In Orders
              </label>
            </div>
            <div className="flex items-center">
              <input id="apply_takeaway" name="apply_takeaway" type="checkbox" checked={formData.apply_takeaway} onChange={handleChange}
                className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
              <label htmlFor="apply_takeaway" className="ml-2 block text-sm text-slate-900 dark:text-slate-300">
                Takeaway / To-Go Orders
              </label>
            </div>
            <div className="flex items-center">
              <input id="apply_delivery" name="apply_delivery" type="checkbox" checked={formData.apply_delivery} onChange={handleChange}
                className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
              <label htmlFor="apply_delivery" className="ml-2 block text-sm text-slate-900 dark:text-slate-300">
                Delivery Orders
              </label>
            </div>
          </div>
        </div>

        <div className="border-t border-slate-200 dark:border-slate-800 pt-6">
          <h4 className="text-sm font-medium text-slate-900 dark:text-white mb-4">Receipt Printing</h4>
          <div className="flex items-center">
            <input id="print_gstin" name="print_gstin" type="checkbox" checked={formData.print_gstin} onChange={handleChange}
              className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
            <label htmlFor="print_gstin" className="ml-2 block text-sm text-slate-900 dark:text-slate-300">
              Print Tax Registration Number (GSTIN/VAT) on Receipts
            </label>
          </div>
        </div>
      </div>

      <div className="mt-8 pt-5 border-t border-slate-200 dark:border-slate-800">
        <div className="flex justify-start">
          <Button onClick={handleSave} disabled={isLoading}>
            {isLoading ? 'Saving...' : 'Save Tax Settings'}
          </Button>
        </div>
      </div>
    </div>
  )
}
