'use client';

import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabaseClient';
import html2pdf from 'html2pdf.js';

export default function ShipmentsPage() {
  const [shipments, setShipments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchShipments();
  }, []);

  async function fetchShipments() {
    setLoading(true);
    // Fetch orders that are deliveries, and left join shipments
    const { data, error } = await supabase
      .from('orders')
      .select('*, customer:customers(first_name, last_name, shipping_address), shipments(*)')
      .eq('order_type', 'DELIVERY')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching shipments:', error);
    } else {
      setShipments(data || []);
    }
    setLoading(false);
  }

  async function updateShipment(orderId: string, shipmentId: string | undefined, payload: any) {
    if (shipmentId) {
      // Update existing
      await supabase.from('shipments').update(payload).eq('id', shipmentId);
    } else {
      // Create new
      const user = await supabase.auth.getUser();
      await supabase.from('shipments').insert([{
        tenant_id: user.data.user?.user_metadata.tenant_id,
        order_id: orderId,
        ...payload
      }]);
    }
    fetchShipments();
  }

  const downloadShipmentPDF = (order: any) => {
    const template = document.getElementById('hidden-invoice-template');
    const placeholder = document.getElementById('invoice-content-placeholder');
    if (!template || !placeholder) return;

    const shipment = order.shipments?.[0] || {};
    
    // Inject content
    placeholder.innerHTML = `
      <div style="margin-bottom: 20px;">
        <h3 style="font-weight: bold; margin-bottom: 5px;">Shipping To:</h3>
        <p>${order.customer?.first_name || ''} ${order.customer?.last_name || ''}</p>
        <p>${order.customer?.shipping_address || 'Address not provided'}</p>
      </div>
      <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
        <tr>
          <td style="padding: 8px; border: 1px solid #ccc; font-weight: bold;">Order Number</td>
          <td style="padding: 8px; border: 1px solid #ccc;">${order.order_number}</td>
        </tr>
        <tr>
          <td style="padding: 8px; border: 1px solid #ccc; font-weight: bold;">Courier</td>
          <td style="padding: 8px; border: 1px solid #ccc;">${shipment.courier_name || 'N/A'}</td>
        </tr>
        <tr>
          <td style="padding: 8px; border: 1px solid #ccc; font-weight: bold;">Tracking Number</td>
          <td style="padding: 8px; border: 1px solid #ccc; text-transform: uppercase;">${shipment.tracking_number || 'N/A'}</td>
        </tr>
        <tr>
          <td style="padding: 8px; border: 1px solid #ccc; font-weight: bold;">Status</td>
          <td style="padding: 8px; border: 1px solid #ccc;">${shipment.status || 'PENDING'}</td>
        </tr>
      </table>
      <p style="text-align: center; margin-top: 40px; font-style: italic;">Track your shipment online using the tracking number above.</p>
    `;

    const clone = template.cloneNode(true) as HTMLElement;
    clone.style.display = 'block';
    clone.style.position = 'static';
    clone.style.width = '210mm'; // A4 width approx
    document.body.appendChild(clone);

    const opt = {
      margin:       10,
      filename:     `Shipment_${order.order_number}.pdf`,
      image:        { type: 'jpeg', quality: 0.98 },
      html2canvas:  { scale: 2 },
      jsPDF:        { unit: 'mm', format: 'a4', orientation: 'portrait' }
    };

    html2pdf().set(opt).from(clone).save().then(() => {
      document.body.removeChild(clone);
    });
  };

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">Courier & Shipment Tracking</h1>

      {loading ? (
        <p>Loading deliveries...</p>
      ) : (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <table className="w-full text-left text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="p-4">Order #</th>
                <th className="p-4">Customer</th>
                <th className="p-4">Shipping Address</th>
                <th className="p-4">Courier</th>
                <th className="p-4">Tracking #</th>
                <th className="p-4">Status</th>
                <th className="p-4">Action</th>
              </tr>
            </thead>
            <tbody>
              {shipments.map((order) => {
                const shipment = order.shipments?.[0] || {};
                const hasShipment = !!shipment.id;

                return (
                  <tr key={order.id} className="border-b hover:bg-gray-50">
                    <td className="p-4 font-medium">{order.order_number}</td>
                    <td className="p-4">{order.customer?.first_name} {order.customer?.last_name}</td>
                    <td className="p-4 text-xs text-gray-500 max-w-[200px] truncate" title={order.customer?.shipping_address}>
                      {order.customer?.shipping_address || 'No address provided'}
                    </td>
                    <td className="p-4">
                      <input 
                        type="text" 
                        placeholder="e.g. Delhivery"
                        className="border rounded px-2 py-1 w-28"
                        defaultValue={shipment.courier_name || ''}
                        onBlur={(e) => {
                          if (e.target.value !== shipment.courier_name) {
                            updateShipment(order.id, shipment.id, { courier_name: e.target.value });
                          }
                        }}
                      />
                    </td>
                    <td className="p-4">
                      <input 
                        type="text" 
                        placeholder="Tracking Number"
                        className="border rounded px-2 py-1 w-36 text-xs uppercase"
                        defaultValue={shipment.tracking_number || ''}
                        onBlur={(e) => {
                          if (e.target.value !== shipment.tracking_number) {
                            updateShipment(order.id, shipment.id, { tracking_number: e.target.value });
                          }
                        }}
                      />
                    </td>
                    <td className="p-4">
                      <select 
                        className="border rounded px-2 py-1"
                        value={shipment.status || 'PENDING'}
                        onChange={(e) => updateShipment(order.id, shipment.id, { status: e.target.value, dispatch_date: e.target.value === 'DISPATCHED' ? new Date().toISOString() : shipment.dispatch_date })}
                      >
                        <option value="PENDING">Pending</option>
                        <option value="DISPATCHED">Dispatched</option>
                        <option value="IN_TRANSIT">In Transit</option>
                        <option value="DELIVERED">Delivered</option>
                        <option value="RETURNED">Returned</option>
                      </select>
                    </td>
                    <td className="p-4 text-xs text-gray-400">
                      {shipment.dispatch_date ? new Date(shipment.dispatch_date).toLocaleDateString() : '-'}
                    </td>
                    <td className="p-4">
                      {hasShipment && (
                        <button 
                          onClick={() => downloadShipmentPDF(order)}
                          className="bg-indigo-100 text-indigo-700 px-3 py-1 rounded text-xs font-semibold hover:bg-indigo-200"
                        >
                          PDF
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
              {shipments.length === 0 && (
                <tr>
                  <td colSpan={8} className="p-8 text-center text-gray-500">No delivery orders found.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Hidden Invoice Template for PDF Generation */}
      <div id="hidden-invoice-template" className="hidden absolute top-0 left-0 w-[800px] bg-white p-8 text-black" style={{ zIndex: -1000 }}>
        <div className="border-b-2 border-black pb-4 mb-4 flex justify-between items-end">
          <div>
            <h1 className="text-3xl font-bold uppercase">AJ's Tea & More</h1>
            <p>123 Hill Station Road, Darjeeling, WB 734101</p>
          </div>
          <div className="text-right">
            <h2 className="text-xl font-bold">SHIPMENT INVOICE</h2>
            <p>Date: {new Date().toLocaleDateString()}</p>
          </div>
        </div>
        
        <div id="invoice-content-placeholder">
          {/* Content injected dynamically */}
        </div>
      </div>
    </div>
  );
}
