'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/utils/supabase/client'
import { useTenant } from '@/hooks/useTenant'
import { Button } from '@/components/ui/button'

export default function BusinessSettingsPage() {
  const supabase = createClient()
  const { outletId, isLoading: tenantLoading } = useTenant()

  const [isLoading, setIsLoading] = useState(false)
  const [formData, setFormData] = useState({
    name: '',
    legal_entity_name: '',
    gstin: '',
    phone: '',
    email: '',
    address: '',
    timezone: 'UTC',
    currency_symbol: '$',
    currency_code: 'USD',
  })

  useEffect(() => {
    if (!outletId) return

    async function fetchSettings() {
      const { data, error } = await supabase
        .from('outlets')
        .select('name, phone, address, settings')
        .eq('id', outletId)
        .single()

      if (data) {
        setFormData({
          name: data.name || '',
          phone: data.phone || '',
          address: data.address || '',
          legal_entity_name: data.settings?.legal_entity_name || '',
          gstin: data.settings?.gstin || '',
          email: data.settings?.email || '',
          timezone: data.settings?.timezone || 'UTC',
          currency_symbol: data.settings?.currency_symbol || '$',
          currency_code: data.settings?.currency_code || 'USD',
        })
      }
    }
    fetchSettings()
  }, [outletId, supabase])

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    setFormData((prev) => ({ ...prev, [e.target.name]: e.target.value }))
  }

  const handleSave = async () => {
    if (!outletId) return
    setIsLoading(true)
    
    // First, fetch current settings to avoid overriding non-business settings
    const { data: currentData } = await supabase
      .from('outlets')
      .select('settings')
      .eq('id', outletId)
      .single()

    const currentSettings = currentData?.settings || {}

    const newSettings = {
      ...currentSettings,
      legal_entity_name: formData.legal_entity_name,
      gstin: formData.gstin,
      email: formData.email,
      timezone: formData.timezone,
      currency_symbol: formData.currency_symbol,
      currency_code: formData.currency_code,
    }

    const { error } = await supabase
      .from('outlets')
      .update({
        name: formData.name,
        phone: formData.phone,
        address: formData.address,
        settings: newSettings
      })
      .eq('id', outletId)

    setIsLoading(false)
    if (!error) {
      alert('Settings saved successfully!')
    } else {
      alert('Failed to save settings: ' + error.message)
    }
  }

  if (tenantLoading) return <div>Loading...</div>

  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <h3 className="text-lg font-medium leading-6 text-slate-900 dark:text-white">Business Settings</h3>
        <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
          Update your store's primary contact details and identity.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
        
        <div className="sm:col-span-3">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Store Name (DBA)</label>
          <div className="mt-1">
            <input type="text" name="name" value={formData.name} onChange={handleChange}
              className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
          </div>
        </div>

        <div className="sm:col-span-3">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Legal Entity Name</label>
          <div className="mt-1">
            <input type="text" name="legal_entity_name" value={formData.legal_entity_name} onChange={handleChange}
              className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
          </div>
        </div>

        <div className="sm:col-span-3">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Tax/GSTIN Number</label>
          <div className="mt-1">
            <input type="text" name="gstin" value={formData.gstin} onChange={handleChange}
              className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
          </div>
        </div>

        <div className="sm:col-span-3">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Phone Number</label>
          <div className="mt-1">
            <input type="text" name="phone" value={formData.phone} onChange={handleChange}
              className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
          </div>
        </div>

        <div className="sm:col-span-6">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Support Email</label>
          <div className="mt-1">
            <input type="email" name="email" value={formData.email} onChange={handleChange}
              className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
          </div>
        </div>

        <div className="sm:col-span-6">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Address</label>
          <div className="mt-1">
            <textarea name="address" rows={3} value={formData.address} onChange={handleChange}
              className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
          </div>
        </div>

        <div className="sm:col-span-2">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Timezone</label>
          <div className="mt-1">
            <select name="timezone" value={formData.timezone} onChange={handleChange}
              className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border">
              <option value="UTC">UTC</option>
              <option value="America/New_York">EST (New York)</option>
              <option value="America/Chicago">CST (Chicago)</option>
              <option value="America/Los_Angeles">PST (Los Angeles)</option>
              <option value="Asia/Kolkata">IST (India)</option>
            </select>
          </div>
        </div>

        <div className="sm:col-span-2">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Currency Symbol</label>
          <div className="mt-1">
            <input type="text" name="currency_symbol" value={formData.currency_symbol} onChange={handleChange}
              className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
          </div>
        </div>

        <div className="sm:col-span-2">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300">Currency Code</label>
          <div className="mt-1">
            <input type="text" name="currency_code" value={formData.currency_code} onChange={handleChange}
              className="block w-full rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm dark:bg-slate-900 dark:border-slate-700 dark:text-white px-3 py-2 border" />
          </div>
        </div>
      </div>

      <div className="mt-8 pt-5 border-t border-slate-200 dark:border-slate-800">
        <div className="flex justify-end">
          <Button onClick={handleSave} disabled={isLoading}>
            {isLoading ? 'Saving...' : 'Save Settings'}
          </Button>
        </div>
      </div>
    </div>
  )
}
