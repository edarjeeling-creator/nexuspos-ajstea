'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/utils/supabase/client'
import { useTenant } from '@/hooks/useTenant'
import { Button } from '@/components/ui/button'

export default function ReceiptSettingsPage() {
  const supabase = createClient()
  const { outletId, isLoading: tenantLoading } = useTenant()
  const [isLoading, setIsLoading] = useState(false)

  const [formData, setFormData] = useState({
    receipt_format: 'thermal_80mm',
    header_text: 'Thank you for dining with us!',
    footer_text: 'Please come again.',
    show_logo: true,
    tax_display: 'inclusive'
  })

  useEffect(() => {
    if (!outletId) return

    async function fetchSettings() {
      const { data, error } = await supabase
        .from('outlets')
        .select('settings')
        .eq('id', outletId)
        .single()

      if (data && data.settings) {
        setFormData({
          receipt_format: data.settings.receipt_format || 'thermal_80mm',
          header_text: data.settings.header_text || 'Thank you for dining with us!',
          footer_text: data.settings.footer_text || 'Please come again.',
          show_logo: data.settings.show_logo !== undefined ? data.settings.show_logo : true,
          tax_display: data.settings.tax_display || 'inclusive'
        })
      }
    }
    fetchSettings()
  }, [outletId, supabase])

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const value = e.target.type === 'checkbox' ? (e.target as HTMLInputElement).checked : e.target.value
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
      receipt_format: formData.receipt_format,
      header_text: formData.header_text,
      footer_text: formData.footer_text,
      show_logo: formData.show_logo,
      tax_display: formData.tax_display
    }

    const { error } = await supabase
      .from('outlets')
      .update({ settings: newSettings })
      .eq('id', outletId)

    setIsLoading(false)
    if (!error) {
      alert('Receipt settings saved successfully!')
    } else {
      alert('Failed to save settings: ' + error.message)
    }
  }

  if (tenantLoading) return <div>Loading...</div>

  return (
    <div className="max-w-4xl grid grid-cols-1 md:grid-cols-2 gap-8">
      <div>
        <div className="mb-6">
          <h3 className="text-lg font-medium leading-6 text-slate-900 dark:text-white">Receipt Settings</h3>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            Customize how your printed receipts look.
          </p>
        </div>

        <div className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Receipt Format</label>
            <div className="mt-1">
              <select name="receipt_format" value={formData.receipt_format} onChange={handleChange}
                className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border">
                <option value="thermal_80mm">Thermal 80mm</option>
                <option value="a4_invoice">A4 Invoice</option>
              </select>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Custom Header Text</label>
            <div className="mt-1">
              <textarea name="header_text" rows={2} value={formData.header_text} onChange={handleChange}
                className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Custom Footer Text</label>
            <div className="mt-1">
              <textarea name="footer_text" rows={2} value={formData.footer_text} onChange={handleChange}
                className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
            </div>
          </div>

          <div className="flex items-center">
            <input id="show_logo" name="show_logo" type="checkbox" checked={formData.show_logo} onChange={handleChange}
              className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
            <label htmlFor="show_logo" className="ml-2 block text-sm text-slate-900 dark:text-slate-300">
              Print Business Logo on Receipt
            </label>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Tax Display</label>
            <div className="mt-1">
              <select name="tax_display" value={formData.tax_display} onChange={handleChange}
                className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border">
                <option value="inclusive">Tax Inclusive (Hidden from line items)</option>
                <option value="exclusive">Tax Exclusive (Added to subtotal)</option>
              </select>
            </div>
          </div>

          <div className="pt-5 border-t border-slate-200 dark:border-slate-800">
            <Button onClick={handleSave} disabled={isLoading}>
              {isLoading ? 'Saving...' : 'Save Settings'}
            </Button>
          </div>
        </div>
      </div>

      {/* Receipt Preview */}
      <div className="bg-slate-50 dark:bg-slate-900 p-6 rounded-lg border border-slate-200 dark:border-slate-800 flex justify-center items-start">
        <div className={`bg-white text-black p-4 shadow-md ${formData.receipt_format === 'thermal_80mm' ? 'w-[300px]' : 'w-[450px]'} font-mono text-xs flex flex-col`}>
          {formData.show_logo && (
            <div className="flex justify-center mb-4">
              <div className="w-12 h-12 bg-slate-200 rounded-full flex items-center justify-center text-slate-500 text-[10px]">LOGO</div>
            </div>
          )}
          <div className="text-center mb-4 whitespace-pre-line font-bold">
            {formData.header_text}
          </div>
          <div className="border-t border-b border-dashed border-black py-2 mb-2 flex justify-between">
            <span>Item</span>
            <span>Total</span>
          </div>
          <div className="flex justify-between mb-1">
            <span>1x Classic Burger</span>
            <span>$12.00</span>
          </div>
          <div className="flex justify-between mb-4">
            <span>2x Coca Cola</span>
            <span>$5.00</span>
          </div>
          <div className="border-t border-dashed border-black pt-2 mb-2">
            <div className="flex justify-between font-bold">
              <span>Total</span>
              <span>$17.00</span>
            </div>
            {formData.tax_display === 'exclusive' && (
              <div className="flex justify-between text-[10px] text-slate-600 mt-1">
                <span>Tax (10%)</span>
                <span>$1.70</span>
              </div>
            )}
          </div>
          <div className="text-center mt-4 whitespace-pre-line italic">
            {formData.footer_text}
          </div>
        </div>
      </div>
    </div>
  )
}
