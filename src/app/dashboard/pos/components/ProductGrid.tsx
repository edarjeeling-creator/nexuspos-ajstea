'use client'

import { useLiveQuery } from 'dexie-react-hooks'
import { posDb, MenuItem } from '@/lib/db/pos-db'
import { usePosStore } from '@/store/usePosStore'
import { Card } from '@/components/ui/card'
import { useState } from 'react'
import { Input } from '@/components/ui/input'
import { Search } from 'lucide-react'
import { useBarcodeScanner } from '@/hooks/useBarcodeScanner'

export function ProductGrid() {
  const [search, setSearch] = useState('')
  const addItem = usePosStore(state => state.addItem)

  const items = useLiveQuery(async () => {
    if (!search) {
      return await posDb.menu_cache.toArray()
    }
    const lowerSearch = search.toLowerCase()
    return await posDb.menu_cache.filter(item => 
      item.name.toLowerCase().includes(lowerSearch) || 
      (item.barcode && item.barcode.includes(lowerSearch))
    ).toArray()
  }, [search])

  useBarcodeScanner({
    onScan: async (barcode) => {
      const item = await posDb.menu_cache.where('barcode').equals(barcode).first()
      if (item && item.is_available) {
        addItem(item)
      } else {
        console.warn('Barcode scanned but item not found or unavailable:', barcode)
      }
    }
  })

  // Mock items if db is empty for MVP visual purposes
  const displayItems = (items && items.length > 0) ? items : [
    { id: '1', name: 'Espresso', price: 3.50, category: 'Coffee', stock_quantity: 100, is_available: true, barcode: '10001' },
    { id: '2', name: 'Latte', price: 4.50, category: 'Coffee', stock_quantity: 50, is_available: true, barcode: '10002' },
    { id: '3', name: 'Croissant', price: 3.00, category: 'Pastry', stock_quantity: 20, is_available: true, barcode: '10003' },
    { id: '4', name: 'Avocado Toast', price: 8.50, category: 'Food', stock_quantity: 15, is_available: true, barcode: '10004' },
    { id: '5', name: 'Orange Juice', price: 4.00, category: 'Drinks', stock_quantity: 30, is_available: true, barcode: '10005' },
    { id: '6', name: 'Blueberry Muffin', price: 3.50, category: 'Pastry', stock_quantity: 12, is_available: true, barcode: '10006' },
  ] as MenuItem[];

  return (
    <div className="flex flex-col h-full gap-4">
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
        <Input 
          className="pl-9 h-12 text-lg bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800" 
          placeholder="Search products or scan barcode..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3 overflow-y-auto pb-4 pr-2">
        {displayItems.map(item => (
          <Card 
            key={item.id} 
            className="p-3 cursor-pointer hover:border-slate-400 dark:hover:border-slate-500 hover:shadow-md transition-all flex flex-col justify-between aspect-square active:scale-95 select-none"
            onClick={() => addItem(item)}
          >
            <div>
              <div className="text-[11px] font-semibold tracking-wider uppercase text-slate-500 dark:text-slate-400 mb-1">{item.category}</div>
              <div className="font-semibold text-sm sm:text-base leading-snug text-slate-900 dark:text-slate-100 line-clamp-2">{item.name}</div>
            </div>
            <div className="flex justify-between items-end mt-2">
              <div className="font-bold text-lg">${item.price.toFixed(2)}</div>
              <div className="text-[10px] text-slate-400 font-medium">Stock: {item.stock_quantity}</div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  )
}
