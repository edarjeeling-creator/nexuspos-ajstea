'use client';

import { useState, useEffect } from 'react';
import { createClient } from '@/utils/supabase/client';
import { Printer } from 'lucide-react';

export default function LabelsPage() {
  const supabase = createClient();
  const [inventoryItems, setInventoryItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const [selectedItem, setSelectedItem] = useState<any>(null);
  const [batchNumber, setBatchNumber] = useState('');
  const [mrp, setMrp] = useState('');
  const [weight, setWeight] = useState('500g'); // Default or custom
  const [packingDate, setPackingDate] = useState(new Date().toISOString().split('T')[0]);

  useEffect(() => {
    fetchItems();
  }, []);

  async function fetchItems() {
    const { data } = await supabase
      .from('inventory_items')
      .select('*')
      .in('item_type', ['FINISHED_GOOD', 'RETAIL']) // Typically we only label finished goods
      .is('deleted_at', null)
      .order('name');
    
    setInventoryItems(data || []);
    setLoading(false);
  }

  const handlePrint = () => {
    if (!selectedItem) {
      alert("Please select an item first");
      return;
    }
    window.print();
  }

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="flex justify-between items-center mb-6 print:hidden">
        <h1 className="text-2xl font-bold">Product Label Printing</h1>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 print:hidden">
        {/* Controls */}
        <div className="bg-white p-6 rounded-lg shadow-md space-y-4">
          <h2 className="text-xl font-semibold mb-4 text-gray-800">Label Configuration</h2>
          
          <div>
            <label className="block text-sm font-medium mb-1">Product</label>
            <select 
              className="w-full border rounded p-2" 
              onChange={e => setSelectedItem(inventoryItems.find(i => i.id === e.target.value))}
            >
              <option value="">Select Product...</option>
              {inventoryItems.map(i => <option key={i.id} value={i.id}>{i.name}</option>)}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Net Weight</label>
            <input type="text" className="w-full border rounded p-2" value={weight} onChange={e => setWeight(e.target.value)} />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Batch Number</label>
            <input type="text" className="w-full border rounded p-2 uppercase" value={batchNumber} onChange={e => setBatchNumber(e.target.value)} />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Packing Date</label>
            <input type="date" className="w-full border rounded p-2" value={packingDate} onChange={e => setPackingDate(e.target.value)} />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">MRP (₹)</label>
            <input type="number" step="0.01" className="w-full border rounded p-2" value={mrp} onChange={e => setMrp(e.target.value)} />
          </div>

          <button 
            onClick={handlePrint}
            className="w-full bg-indigo-600 text-white px-4 py-3 rounded-lg font-bold flex items-center justify-center gap-2 mt-4 hover:bg-indigo-700"
          >
            <Printer className="h-5 w-5" /> Print Label
          </button>
        </div>

        {/* Preview Panel */}
        <div className="bg-gray-100 p-6 rounded-lg flex items-center justify-center min-h-[400px]">
          {selectedItem ? (
            <div className="text-center">
              <p className="text-sm text-gray-500 mb-2">Live Preview</p>
              <LabelTemplate 
                item={selectedItem} 
                batch={batchNumber} 
                mrp={mrp} 
                weight={weight} 
                date={packingDate} 
              />
            </div>
          ) : (
            <p className="text-gray-400">Select a product to preview label</p>
          )}
        </div>
      </div>

      {/* Hidden Print Container */}
      <div className="hidden print:block absolute top-0 left-0 w-[50mm] h-[25mm] bg-white m-0 p-0">
        {selectedItem && (
          <LabelTemplate 
            item={selectedItem} 
            batch={batchNumber} 
            mrp={mrp} 
            weight={weight} 
            date={packingDate} 
            forPrint={true}
          />
        )}
      </div>

      <style dangerouslySetInnerHTML={{__html: `
        @media print {
          body * { visibility: hidden; }
          .print\\:block, .print\\:block * { visibility: visible; }
          @page {
            size: 50mm 25mm; /* Standard thermal label size */
            margin: 0;
          }
        }
      `}} />
    </div>
  );
}

function LabelTemplate({ item, batch, mrp, weight, date, forPrint = false }: any) {
  // Simple CSS barcode simulation using a web font or just a placeholder box
  // For production, a library like react-barcode would be used.
  return (
    <div className={`bg-white border-2 border-black flex flex-col justify-between p-1 overflow-hidden
      ${forPrint ? 'w-[50mm] h-[25mm]' : 'w-[200px] h-[100px] shadow-lg'}
    `}>
      <div className="text-center">
        <h3 className={`font-bold uppercase truncate leading-tight ${forPrint ? 'text-[9px]' : 'text-xs'}`}>
          {item.name}
        </h3>
        <p className={`font-semibold ${forPrint ? 'text-[8px]' : 'text-[10px]'} leading-tight`}>
          Net Wt: {weight}
        </p>
      </div>
      
      <div className="flex justify-between px-1">
        <div className={`text-left leading-tight ${forPrint ? 'text-[6px]' : 'text-[8px]'}`}>
          <p>Batch: {batch}</p>
          <p>Pkd: {date}</p>
        </div>
        <div className={`text-right font-bold leading-tight ${forPrint ? 'text-[8px]' : 'text-[10px]'}`}>
          <p>MRP: ₹{mrp}</p>
          <p className={`${forPrint ? 'text-[5px]' : 'text-[6px]'} font-normal`}>(Incl. all taxes)</p>
        </div>
      </div>

      {/* Barcode Placeholder / String */}
      <div className="text-center mt-1">
        <div className="font-mono bg-gray-100 text-center tracking-widest border border-gray-300"
             style={{ fontSize: forPrint ? '7px' : '9px', padding: '1px' }}>
          *{item.barcode || item.item_code || 'NO-CODE'}*
        </div>
      </div>
    </div>
  );
}
