'use client';

import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabaseClient';

export default function CustomersPage() {
  const [customers, setCustomers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  
  const [formData, setFormData] = useState({
    first_name: '',
    last_name: '',
    email: '',
    phone: '',
    gstin: '',
    shipping_address: ''
  });

  useEffect(() => {
    fetchCustomers();
  }, []);

  async function fetchCustomers() {
    setLoading(true);
    const { data: custData, error } = await supabase
      .from('customers')
      .select('*, orders(id, grand_total, created_at, order_number)')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching customers:', error);
    } else {
      // Calculate totals
      const enriched = (custData || []).map((c: any) => {
        const totalSpent = c.orders?.reduce((sum: number, o: any) => sum + (o.grand_total || 0), 0) || 0;
        const totalOrders = c.orders?.length || 0;
        const lastOrderDate = c.orders?.length > 0 
          ? new Date(Math.max(...c.orders.map((o:any) => new Date(o.created_at).getTime()))).toLocaleDateString()
          : '-';

        return { ...c, totalSpent, totalOrders, lastOrderDate };
      });
      setCustomers(enriched);
    }
    setLoading(false);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const { error } = await supabase.from('customers').insert([
      {
        first_name: formData.first_name,
        last_name: formData.last_name,
        email: formData.email,
        phone: formData.phone,
        gstin: formData.gstin,
        shipping_address: formData.shipping_address,
        tenant_id: (await supabase.auth.getUser()).data.user?.user_metadata.tenant_id
      }
    ]);

    if (error) {
      alert('Failed to save customer');
    } else {
      setShowForm(false);
      setFormData({ first_name: '', last_name: '', email: '', phone: '', gstin: '', shipping_address: '' });
      fetchCustomers();
    }
  }

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Customer Database</h1>
        <button 
          onClick={() => setShowForm(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
        >
          + Add Customer
        </button>
      </div>

      {showForm && (
        <div className="bg-white p-6 rounded-lg shadow-md mb-8">
          <h2 className="text-xl font-semibold mb-4">New Customer</h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">First Name</label>
              <input required type="text" className="w-full border rounded p-2" value={formData.first_name} onChange={e => setFormData({...formData, first_name: e.target.value})} />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Last Name</label>
              <input type="text" className="w-full border rounded p-2" value={formData.last_name} onChange={e => setFormData({...formData, last_name: e.target.value})} />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Phone</label>
              <input required type="tel" className="w-full border rounded p-2" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Email</label>
              <input type="email" className="w-full border rounded p-2" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">GSTIN (Optional)</label>
              <input type="text" className="w-full border rounded p-2" value={formData.gstin} onChange={e => setFormData({...formData, gstin: e.target.value})} />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Shipping Address (Optional)</label>
              <input type="text" className="w-full border rounded p-2" value={formData.shipping_address} onChange={e => setFormData({...formData, shipping_address: e.target.value})} />
            </div>
            <div className="col-span-2 flex justify-end gap-2 mt-4">
              <button type="button" onClick={() => setShowForm(false)} className="px-4 py-2 text-gray-600">Cancel</button>
              <button type="submit" className="bg-blue-600 text-white px-4 py-2 rounded-lg">Save</button>
            </div>
          </form>
        </div>
      )}

      {loading ? (
        <p>Loading customers...</p>
      ) : (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <table className="w-full text-left text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="p-4">Name</th>
                <th className="p-4">Contact</th>
                <th className="p-4">GSTIN & Address</th>
                <th className="p-4">Orders</th>
                <th className="p-4 text-right">Total Spent</th>
                <th className="p-4">Last Order</th>
              </tr>
            </thead>
            <tbody>
              {customers.map((c) => (
                <tr key={c.id} className="border-b hover:bg-gray-50 align-top">
                  <td className="p-4 font-medium">{c.first_name} {c.last_name}</td>
                  <td className="p-4">
                    <div className="text-gray-900">{c.phone}</div>
                    <div className="text-gray-500 text-xs">{c.email}</div>
                  </td>
                  <td className="p-4">
                    <div className="font-mono text-indigo-700">{c.gstin || '-'}</div>
                    <div className="text-gray-500 text-xs mt-1 max-w-[200px]">{c.shipping_address || 'No address'}</div>
                  </td>
                  <td className="p-4">
                    <span className="bg-gray-100 text-gray-800 px-2 py-1 rounded text-xs font-bold">{c.totalOrders}</span>
                  </td>
                  <td className="p-4 text-right font-bold text-green-700">${c.totalSpent.toFixed(2)}</td>
                  <td className="p-4 text-gray-600">{c.lastOrderDate}</td>
                </tr>
              ))}
              {customers.length === 0 && (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-gray-500">No customers found.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
