'use client'

import { useState, useEffect, useMemo, useRef } from 'react'
import { getPosData, placeOrder, PlaceOrderPayload } from './actions'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Search, ShoppingCart, Minus, Plus, X, User, Printer, CreditCard, Banknote, Smartphone, Layers } from 'lucide-react'
import { Input } from '@/components/ui/input'
import { toast } from 'sonner'
import Receipt from './Receipt'

// Types
type Category = { id: string; name: string }
type MenuItem = { id: string; name: string; price: number; category_id: string; tax_rate?: number; tax_inclusive?: boolean; item_code?: string }
type Customer = { id: string; first_name: string; last_name: string; gstin?: string }
type CartItem = MenuItem & { cartId: string; quantity: number }

export default function PosTerminal() {
  const [categories, setCategories] = useState<Category[]>([])
  const [menuItems, setMenuItems] = useState<MenuItem[]>([])
  const [customers, setCustomers] = useState<Customer[]>([])
  const [loading, setLoading] = useState(true)

  const [activeCategory, setActiveCategory] = useState<string | null>(null)
  const [searchQuery, setSearchQuery] = useState('')
  
  const [cart, setCart] = useState<CartItem[]>([])
  const [orderType, setOrderType] = useState('DINE_IN')
  const [selectedCustomer, setSelectedCustomer] = useState<string | null>(null)
  
  const [isProcessing, setIsProcessing] = useState(false)
  const [showPayment, setShowPayment] = useState(false)
  const [paymentMethod, setPaymentMethod] = useState('CASH')

  // Receipt State
  const [lastOrder, setLastOrder] = useState<any>(null)
  const receiptRef = useRef<HTMLDivElement>(null)

  // Barcode Scanner State
  const barcodeBuffer = useRef<string>('')
  const barcodeTimer = useRef<NodeJS.Timeout | null>(null)

  useEffect(() => {
    getPosData().then((data) => {
      setCategories(data.categories)
      setMenuItems(data.menuItems)
      setCustomers(data.customers)
      setLoading(false)
    })
  }, [])

  // Barcode Listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Ignore if typing in an input field (except body)
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return;
      }

      if (e.key === 'Enter') {
        if (barcodeBuffer.current.length > 2) {
          const scannedCode = barcodeBuffer.current;
          // Find item by item_code (barcode)
          const matchedItem = menuItems.find(item => item.item_code === scannedCode);
          if (matchedItem) {
            addToCart(matchedItem);
            toast.success(`Scanned: ${matchedItem.name}`);
          } else {
            toast.error(`Barcode not found: ${scannedCode}`);
          }
        }
        barcodeBuffer.current = '';
        if (barcodeTimer.current) clearTimeout(barcodeTimer.current);
      } else {
        // Collect characters
        if (e.key.length === 1) {
          barcodeBuffer.current += e.key;
          if (barcodeTimer.current) clearTimeout(barcodeTimer.current);
          barcodeTimer.current = setTimeout(() => {
            barcodeBuffer.current = ''; // clear if too slow (not a scanner)
          }, 50); // 50ms threshold
        }
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [menuItems]); // Re-bind when menuItems loads

  // Filtered items
  const filteredItems = useMemo(() => {
    return menuItems.filter(item => {
      const matchesCat = activeCategory ? item.category_id === activeCategory : true;
      const matchesSearch = item.name.toLowerCase().includes(searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    })
  }, [menuItems, activeCategory, searchQuery])

  // Cart logic
  const addToCart = (item: MenuItem) => {
    setCart(prev => {
      const existing = prev.find(i => i.id === item.id)
      if (existing) {
        return prev.map(i => i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i)
      }
      return [...prev, { ...item, cartId: Math.random().toString(), quantity: 1 }]
    })
  }

  const updateQuantity = (cartId: string, delta: number) => {
    setCart(prev => prev.map(i => {
      if (i.cartId === cartId) {
        const newQty = i.quantity + delta
        return newQty > 0 ? { ...i, quantity: newQty } : i
      }
      return i
    }))
  }

  const removeFromCart = (cartId: string) => {
    setCart(prev => prev.filter(i => i.cartId !== cartId))
  }

  // Calculations
  const cartTotals = useMemo(() => {
    let subtotal = 0;
    let taxTotal = 0;

    cart.forEach(item => {
      const lineTotal = item.price * item.quantity;
      const taxRate = item.tax_rate || 0; // percentage
      
      if (item.tax_inclusive) {
        // Tax is included in the price
        const basePrice = lineTotal / (1 + (taxRate / 100));
        const tax = lineTotal - basePrice;
        subtotal += basePrice;
        taxTotal += tax;
      } else {
        // Tax is added on top
        const tax = lineTotal * (taxRate / 100);
        subtotal += lineTotal;
        taxTotal += tax;
      }
    })

    const grandTotal = subtotal + taxTotal;

    return { subtotal, taxTotal, grandTotal, discountTotal: 0 }
  }, [cart])

  const handleCheckout = async () => {
    if (cart.length === 0) return toast.error("Cart is empty");
    setShowPayment(true);
  }

  const completePayment = async () => {
    setIsProcessing(true)
    try {
      const payload: PlaceOrderPayload = {
        orderType,
        customerId: selectedCustomer,
        items: cart.map(i => ({
          id: i.id,
          quantity: i.quantity,
          price: i.price,
          tax_amount: (i.tax_inclusive ? (i.price - (i.price / (1 + ((i.tax_rate||0)/100)))) : (i.price * ((i.tax_rate||0)/100))) * i.quantity,
          discount_amount: 0
        })),
        subtotal: cartTotals.subtotal,
        taxTotal: cartTotals.taxTotal,
        discountTotal: cartTotals.discountTotal,
        grandTotal: cartTotals.grandTotal,
        paymentMethod,
        paymentAmount: cartTotals.grandTotal
      }

      const res = await placeOrder(payload)
      
      toast.success(`Order ${res.orderNumber} Completed!`)
      
      // Save for receipt
      const matchedCustomer = customers.find(c => c.id === selectedCustomer);
      setLastOrder({
        orderNumber: res.orderNumber,
        invoiceNumber: res.invoiceNumber,
        items: cart,
        ...cartTotals,
        paymentMethod,
        orderType,
        customer: matchedCustomer || null
      })

      // Reset cart
      setCart([])
      setShowPayment(false)
      
      // Trigger Print
      setTimeout(() => {
        window.print()
      }, 500)

    } catch (e: any) {
      toast.error(e.message)
    } finally {
      setIsProcessing(false)
    }
  }

  if (loading) return <div className="p-8 text-center">Loading POS...</div>

  return (
    <div className="flex flex-col h-[calc(100vh-80px)] overflow-hidden">
      
      {/* Hidden Receipt for Printing */}
      <div className="hidden print:block">
        {lastOrder && <Receipt order={lastOrder} />}
      </div>

      <div className="flex flex-1 overflow-hidden print:hidden">
        
        {/* Left Pane: Categories & Grid */}
        <div className="flex-1 flex flex-col border-r bg-white dark:bg-slate-900">
          {/* Top Bar: Search & Filters */}
          <div className="p-4 border-b flex gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-3 h-4 w-4 text-slate-400" />
              <Input 
                placeholder="Search menu items..." 
                className="pl-9 bg-slate-100 dark:bg-slate-800 border-none"
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
              />
            </div>
          </div>

          <div className="flex flex-1 overflow-hidden">
            {/* Category Sidebar */}
            <div className="w-24 md:w-32 bg-slate-50 dark:bg-slate-950 border-r overflow-y-auto">
              <button
                className={`w-full p-4 text-xs font-medium text-center border-b hover:bg-slate-200 dark:hover:bg-slate-800 transition-colors ${activeCategory === null ? 'bg-indigo-100 text-indigo-700 dark:bg-indigo-900 dark:text-indigo-300' : ''}`}
                onClick={() => setActiveCategory(null)}
              >
                All Items
              </button>
              {categories.map(cat => (
                <button
                  key={cat.id}
                  className={`w-full p-4 text-xs font-medium text-center border-b hover:bg-slate-200 dark:hover:bg-slate-800 transition-colors ${activeCategory === cat.id ? 'bg-indigo-100 text-indigo-700 dark:bg-indigo-900 dark:text-indigo-300' : ''}`}
                  onClick={() => setActiveCategory(cat.id)}
                >
                  {cat.name}
                </button>
              ))}
            </div>

            {/* Product Grid */}
            <div className="flex-1 p-4 overflow-y-auto bg-slate-100/50 dark:bg-slate-900/50">
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
                {filteredItems.map(item => (
                  <button
                    key={item.id}
                    onClick={() => addToCart(item)}
                    className="flex flex-col text-left p-4 bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 hover:border-indigo-500 hover:shadow-md transition-all active:scale-95"
                  >
                    <div className="font-semibold text-sm line-clamp-2 min-h-[40px]">{item.name}</div>
                    <div className="mt-auto pt-2 font-bold text-indigo-600 dark:text-indigo-400">
                      ${item.price.toFixed(2)}
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Right Pane: Cart */}
        <div className="w-80 md:w-96 flex flex-col bg-white dark:bg-slate-900 relative">
          
          {/* Order Type & Customer */}
          <div className="p-4 border-b space-y-3">
            <div className="flex gap-2 bg-slate-100 dark:bg-slate-800 p-1 rounded-lg">
              {['DINE_IN', 'TAKEAWAY', 'DELIVERY'].map(type => (
                <button
                  key={type}
                  onClick={() => setOrderType(type)}
                  className={`flex-1 text-xs py-2 rounded-md font-medium transition-colors ${orderType === type ? 'bg-white dark:bg-slate-700 shadow-sm' : 'text-slate-500'}`}
                >
                  {type.replace('_', ' ')}
                </button>
              ))}
            </div>
            
            <div className="flex items-center gap-2">
              <User className="h-4 w-4 text-slate-500" />
              <select 
                className="flex-1 text-sm bg-transparent border-none focus:ring-0"
                value={selectedCustomer || ''}
                onChange={e => setSelectedCustomer(e.target.value || null)}
              >
                <option value="">Walk-in Customer</option>
                {customers.map(c => (
                  <option key={c.id} value={c.id}>{c.first_name} {c.last_name}</option>
                ))}
              </select>
            </div>
          </div>

          {/* Cart Items */}
          <div className="flex-1 overflow-y-auto p-2">
            {cart.length === 0 ? (
              <div className="h-full flex flex-col items-center justify-center text-slate-400 gap-4">
                <ShoppingCart className="h-12 w-12 opacity-20" />
                <p>Cart is empty</p>
              </div>
            ) : (
              <div className="space-y-2">
                {cart.map(item => (
                  <div key={item.cartId} className="flex gap-2 items-center p-2 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-100 dark:border-slate-800">
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-semibold truncate">{item.name}</div>
                      <div className="text-xs text-slate-500">${item.price.toFixed(2)}</div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button onClick={() => updateQuantity(item.cartId, -1)} className="p-1.5 bg-slate-200 dark:bg-slate-700 rounded-md hover:bg-slate-300"><Minus className="h-3 w-3" /></button>
                      <span className="w-4 text-center text-sm font-medium">{item.quantity}</span>
                      <button onClick={() => updateQuantity(item.cartId, 1)} className="p-1.5 bg-slate-200 dark:bg-slate-700 rounded-md hover:bg-slate-300"><Plus className="h-3 w-3" /></button>
                    </div>
                    <div className="w-16 text-right font-medium text-sm">
                      ${(item.price * item.quantity).toFixed(2)}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Totals & Checkout */}
          <div className="border-t bg-slate-50 dark:bg-slate-950 p-4 space-y-3">
            <div className="flex justify-between text-sm text-slate-600 dark:text-slate-400">
              <span>Subtotal</span>
              <span>${cartTotals.subtotal.toFixed(2)}</span>
            </div>
            <div className="flex justify-between text-sm text-slate-600 dark:text-slate-400">
              <span>Tax</span>
              <span>${cartTotals.taxTotal.toFixed(2)}</span>
            </div>
            <div className="flex justify-between font-bold text-xl pt-2 border-t">
              <span>Total</span>
              <span>${cartTotals.grandTotal.toFixed(2)}</span>
            </div>
            
            <Button 
              className="w-full h-14 text-lg font-bold bg-indigo-600 hover:bg-indigo-700 text-white" 
              onClick={handleCheckout}
              disabled={cart.length === 0}
            >
              Checkout
            </Button>
          </div>

          {/* Payment Modal Overlay */}
          {showPayment && (
            <div className="absolute inset-0 bg-white dark:bg-slate-900 z-10 flex flex-col">
              <div className="p-4 border-b flex justify-between items-center">
                <h3 className="font-bold text-lg">Payment</h3>
                <button onClick={() => setShowPayment(false)} className="p-2"><X className="h-5 w-5" /></button>
              </div>
              <div className="p-6 flex-1 overflow-y-auto space-y-6">
                <div className="text-center space-y-2">
                  <div className="text-sm text-slate-500">Amount Due</div>
                  <div className="text-4xl font-bold">${cartTotals.grandTotal.toFixed(2)}</div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <button onClick={() => setPaymentMethod('CASH')} className={`p-4 flex flex-col items-center gap-2 border-2 rounded-xl transition-all ${paymentMethod === 'CASH' ? 'border-indigo-500 bg-indigo-50 dark:bg-indigo-950/30 text-indigo-700' : 'border-slate-200 dark:border-slate-800 text-slate-600'}`}>
                    <Banknote className="h-8 w-8" />
                    <span className="font-medium">Cash</span>
                  </button>
                  <button onClick={() => setPaymentMethod('CREDIT_CARD')} className={`p-4 flex flex-col items-center gap-2 border-2 rounded-xl transition-all ${paymentMethod === 'CREDIT_CARD' ? 'border-indigo-500 bg-indigo-50 dark:bg-indigo-950/30 text-indigo-700' : 'border-slate-200 dark:border-slate-800 text-slate-600'}`}>
                    <CreditCard className="h-8 w-8" />
                    <span className="font-medium">Card</span>
                  </button>
                  <button onClick={() => setPaymentMethod('UPI')} className={`p-4 flex flex-col items-center gap-2 border-2 rounded-xl transition-all ${paymentMethod === 'UPI' ? 'border-indigo-500 bg-indigo-50 dark:bg-indigo-950/30 text-indigo-700' : 'border-slate-200 dark:border-slate-800 text-slate-600'}`}>
                    <Smartphone className="h-8 w-8" />
                    <span className="font-medium">UPI</span>
                  </button>
                  <button onClick={() => setPaymentMethod('SPLIT')} className={`p-4 flex flex-col items-center gap-2 border-2 rounded-xl transition-all ${paymentMethod === 'SPLIT' ? 'border-indigo-500 bg-indigo-50 dark:bg-indigo-950/30 text-indigo-700' : 'border-slate-200 dark:border-slate-800 text-slate-600'}`}>
                    <Layers className="h-8 w-8" />
                    <span className="font-medium">Split</span>
                  </button>
                </div>
              </div>
              <div className="p-4 border-t">
                <Button 
                  className="w-full h-14 text-lg font-bold bg-green-600 hover:bg-green-700 text-white" 
                  onClick={completePayment}
                  disabled={isProcessing}
                >
                  {isProcessing ? 'Processing...' : 'Complete Payment'}
                </Button>
              </div>
            </div>
          )}

        </div>
      </div>
    </div>
  )
}
