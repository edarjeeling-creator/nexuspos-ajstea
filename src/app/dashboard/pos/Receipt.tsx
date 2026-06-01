'use client'

import html2pdf from 'html2pdf.js'

export default function Receipt({ order }: { order: any }) {
  const receiptRef = React.useRef<HTMLDivElement>(null)

  if (!order) return null

  const handleDownloadPDF = () => {
    if (!receiptRef.current) return;
    const element = receiptRef.current;
    
    // Create a temporary clone for PDF generation to override print hiding
    const clone = element.cloneNode(true) as HTMLElement;
    clone.style.visibility = 'visible';
    clone.style.position = 'static';
    clone.style.width = '80mm'; // Maintain receipt width
    // Append to body temporarily
    document.body.appendChild(clone);

    const opt = {
      margin:       1,
      filename:     `Invoice_${order.invoiceNumber}.pdf`,
      image:        { type: 'jpeg', quality: 0.98 },
      html2canvas:  { scale: 2, useCORS: true },
      jsPDF:        { unit: 'mm', format: [80, 200], orientation: 'portrait' } // Custom receipt format
    };

    html2pdf().set(opt).from(clone).save().then(() => {
      document.body.removeChild(clone);
    });
  }

  return (
    <div className="relative">
      <div className="mb-4 text-center print:hidden">
        <button 
          onClick={handleDownloadPDF}
          className="bg-green-600 text-white px-4 py-2 rounded-lg font-bold shadow hover:bg-green-700"
        >
          Download PDF for WhatsApp
        </button>
      </div>

      <div ref={receiptRef} className="p-4 w-[80mm] mx-auto bg-white text-black font-mono text-sm leading-tight print:w-full print:m-0 print:p-0">
        
        {/* Header */}
        <div className="text-center mb-4">
          <h1 className="text-xl font-bold mb-1">AJ's Tea & More</h1>
          <p className="text-xs">123 Hill Station Road<br/>Darjeeling, WB 734101</p>
          <p className="text-xs mt-1">Tel: +91 98765 43210</p>
        </div>

        <div className="border-t border-b border-dashed border-gray-400 py-2 my-2 text-xs">
          {order.customer?.gstin && <div className="text-center font-bold mb-2 pb-1 border-b border-gray-300">TAX INVOICE</div>}
          <div className="flex justify-between"><span>Order #:</span> <span>{order.orderNumber}</span></div>
          <div className="flex justify-between"><span>Invoice #:</span> <span>{order.invoiceNumber}</span></div>
          <div className="flex justify-between"><span>Date:</span> <span>{new Date().toLocaleString()}</span></div>
          <div className="flex justify-between"><span>Type:</span> <span>{order.orderType?.replace('_', ' ')}</span></div>
          
          {order.customer && (
            <div className="mt-2 pt-2 border-t border-gray-300">
              <div><strong>Billed To:</strong> {order.customer.first_name} {order.customer.last_name}</div>
              {order.customer.shipping_address && <div>{order.customer.shipping_address}</div>}
              {order.customer.gstin && <div><strong>GSTIN:</strong> {order.customer.gstin}</div>}
            </div>
          )}
        </div>

        {/* Items */}
        <div className="py-2 space-y-2">
          <div className="flex font-bold border-b border-gray-400 pb-1">
            <span className="flex-1">Item</span>
            <span className="w-8 text-center">Qty</span>
            <span className="w-16 text-right">Total</span>
          </div>
          {order.items.map((item: any, i: number) => (
            <div key={i} className="flex text-xs">
              <span className="flex-1 pr-2">{item.name}</span>
              <span className="w-8 text-center">{item.quantity}</span>
              <span className="w-16 text-right">${(item.price * item.quantity).toFixed(2)}</span>
            </div>
          ))}
        </div>

        {/* Totals */}
        <div className="border-t border-dashed border-gray-400 pt-2 mt-2 space-y-1">
          <div className="flex justify-between text-xs">
            <span>Subtotal:</span>
            <span>${order.subtotal?.toFixed(2)}</span>
          </div>
          <div className="flex justify-between text-xs">
            <span>Tax:</span>
            <span>${order.taxTotal?.toFixed(2)}</span>
          </div>
          <div className="flex justify-between font-bold text-lg pt-1 border-t border-gray-400 mt-1">
            <span>TOTAL:</span>
            <span>${order.grandTotal?.toFixed(2)}</span>
          </div>
        </div>

        {/* Footer */}
        <div className="border-t border-dashed border-gray-400 pt-2 mt-4 text-center text-xs space-y-1">
          <p>Paid via: {order.paymentMethod}</p>
          <p className="mt-2 font-bold italic">Thank you for your visit!</p>
          <p className="text-[10px] mt-4">Powered by NexusPOS AI</p>
        </div>

        {/* CSS to control printing */}
        <style dangerouslySetInnerHTML={{__html: `
          @media print {
            body * { visibility: hidden; }
            .print\\:block, .print\\:block * { visibility: visible; }
            .print\\:block {
              position: absolute;
              left: 0;
              top: 0;
              width: 80mm; /* Standard thermal receipt width */
            }
            @page {
              margin: 0;
            }
          }
        `}} />
      </div>
    </div>
  )
}
