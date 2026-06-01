'use client';

import { useState, useEffect } from 'react';
import { createClient } from '@/utils/supabase/client';

export default function StockConversionsPage() {
  const supabase = createClient();
  const [conversions, setConversions] = useState<any[]>([]);
  const [inventoryItems, setInventoryItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  
  const [formData, setFormData] = useState({
    source_item_id: '',
    target_item_id: '',
    source_qty_deducted: '',
    target_qty_produced: '',
    batch_number: '',
    notes: ''
  });

  useEffect(() => {
    fetchData();
  }, []);

  async function fetchData() {
    setLoading(true);
    const [convRes, invRes] = await Promise.all([
      supabase.from('stock_conversions').select('*, source:inventory_items!source_item_id(name), target:inventory_items!target_item_id(name)').order('created_at', { ascending: false }),
      supabase.from('inventory_items').select('*').is('deleted_at', null).order('name')
    ]);

    setConversions(convRes.data || []);
    setInventoryItems(invRes.data || []);
    setLoading(false);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const user = await supabase.auth.getUser();
    const tenantId = user.data.user?.user_metadata.tenant_id;
    const userId = user.data.user?.id;

    // 1. Insert Conversion Record
    const { data: conv, error: convErr } = await supabase.from('stock_conversions').insert([{
      tenant_id: tenantId,
      source_item_id: formData.source_item_id,
      target_item_id: formData.target_item_id,
      source_qty_deducted: parseFloat(formData.source_qty_deducted),
      target_qty_produced: parseFloat(formData.target_qty_produced),
      batch_number: formData.batch_number,
      notes: formData.notes,
      created_by: userId
    }]).select().single();

    if (convErr || !conv) {
      alert('Failed to save conversion');
      return;
    }

    // 2. Insert Ledger Entries (Deduction & Addition)
    const txs = [
      {
        tenant_id: tenantId,
        inventory_item_id: formData.source_item_id,
        transaction_type: 'ADJUSTMENT',
        quantity_change: -parseFloat(formData.source_qty_deducted),
        unit_cost: 0, // Ignoring cost logic for now per requirements
        reference_type: 'MANUAL_ADJUSTMENT',
        reference_id: conv.id,
        batch_number: formData.batch_number,
        notes: `Converted to ${formData.target_item_id}`,
        created_by: userId
      },
      {
        tenant_id: tenantId,
        inventory_item_id: formData.target_item_id,
        transaction_type: 'ADJUSTMENT',
        quantity_change: parseFloat(formData.target_qty_produced),
        unit_cost: 0,
        reference_type: 'MANUAL_ADJUSTMENT',
        reference_id: conv.id,
        batch_number: formData.batch_number,
        notes: `Converted from ${formData.source_item_id}`,
        created_by: userId
      }
    ];

    await supabase.from('inventory_transactions').insert(txs);

    setShowForm(false);
    setFormData({ source_item_id: '', target_item_id: '', source_qty_deducted: '', target_qty_produced: '', batch_number: '', notes: '' });
    fetchData();
  }

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Tea Packaging & Stock Conversions</h1>
        <button 
          onClick={() => setShowForm(true)}
          className="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700"
        >
          + New Conversion
        </button>
      </div>

      {showForm && (
        <div className="bg-white p-6 rounded-lg shadow-md mb-8">
          <h2 className="text-xl font-semibold mb-4 text-indigo-700">Package Bulk Tea</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-2 gap-6">
            
            <div className="border p-4 rounded-lg bg-red-50">
              <h3 className="font-bold text-red-700 mb-2">Source (Deduct)</h3>
              <div className="space-y-3">
                <div>
                  <label className="block text-sm font-medium mb-1">Bulk Item</label>
                  <select required className="w-full border rounded p-2" value={formData.source_item_id} onChange={e => setFormData({...formData, source_item_id: e.target.value})}>
                    <option value="">Select Bulk Material...</option>
                    {inventoryItems.map(i => <option key={i.id} value={i.id}>{i.name} ({i.unit_of_measure})</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium mb-1">Quantity Deducted</label>
                  <input required type="number" step="0.01" className="w-full border rounded p-2" value={formData.source_qty_deducted} onChange={e => setFormData({...formData, source_qty_deducted: e.target.value})} />
                </div>
              </div>
            </div>

            <div className="border p-4 rounded-lg bg-green-50">
              <h3 className="font-bold text-green-700 mb-2">Target (Produce)</h3>
              <div className="space-y-3">
                <div>
                  <label className="block text-sm font-medium mb-1">Packaged Item</label>
                  <select required className="w-full border rounded p-2" value={formData.target_item_id} onChange={e => setFormData({...formData, target_item_id: e.target.value})}>
                    <option value="">Select Finished Good...</option>
                    {inventoryItems.map(i => <option key={i.id} value={i.id}>{i.name} ({i.unit_of_measure})</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium mb-1">Quantity Produced</label>
                  <input required type="number" step="0.01" className="w-full border rounded p-2" value={formData.target_qty_produced} onChange={e => setFormData({...formData, target_qty_produced: e.target.value})} />
                </div>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Batch Number</label>
              <input type="text" className="w-full border rounded p-2 uppercase" placeholder="e.g. BATCH-2026-A" value={formData.batch_number} onChange={e => setFormData({...formData, batch_number: e.target.value})} />
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Notes</label>
              <input type="text" className="w-full border rounded p-2" value={formData.notes} onChange={e => setFormData({...formData, notes: e.target.value})} />
            </div>

            <div className="col-span-2 flex justify-end gap-2 mt-2">
              <button type="button" onClick={() => setShowForm(false)} className="px-4 py-2 text-gray-600">Cancel</button>
              <button type="submit" className="bg-indigo-600 text-white px-6 py-2 rounded-lg font-bold">Execute Conversion</button>
            </div>
          </form>
        </div>
      )}

      {loading ? (
        <p>Loading conversions...</p>
      ) : (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <table className="w-full text-left text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="p-4">Date</th>
                <th className="p-4">Source Item</th>
                <th className="p-4 text-red-600">Qty Deducted</th>
                <th className="p-4">Target Item</th>
                <th className="p-4 text-green-600">Qty Produced</th>
                <th className="p-4">Batch #</th>
              </tr>
            </thead>
            <tbody>
              {conversions.map((c) => (
                <tr key={c.id} className="border-b hover:bg-gray-50">
                  <td className="p-4 text-gray-500">{new Date(c.created_at).toLocaleString()}</td>
                  <td className="p-4 font-medium">{c.source?.name}</td>
                  <td className="p-4 font-bold text-red-600">-{c.source_qty_deducted}</td>
                  <td className="p-4 font-medium">{c.target?.name}</td>
                  <td className="p-4 font-bold text-green-600">+{c.target_qty_produced}</td>
                  <td className="p-4 text-gray-500">{c.batch_number || '-'}</td>
                </tr>
              ))}
              {conversions.length === 0 && (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-gray-500">No stock conversions recorded yet.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
