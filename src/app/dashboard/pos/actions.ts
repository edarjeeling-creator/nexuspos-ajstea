'use server'

import { createClient } from '@/utils/supabase/server'

export async function getPosData() {
  const supabase = await createClient()
  
  const [categoriesRes, menuItemsRes, customersRes] = await Promise.all([
    supabase.from('categories').select('*').is('deleted_at', null).order('name'),
    supabase.from('menu_items').select('*, item_code').is('deleted_at', null).eq('is_available', true).order('name'),
    supabase.from('customers').select('*').is('deleted_at', null).order('first_name')
  ])

  return {
    categories: categoriesRes.data || [],
    menuItems: menuItemsRes.data || [],
    customers: customersRes.data || []
  }
}

export type PlaceOrderPayload = {
  orderType: string;
  customerId: string | null;
  items: any[];
  subtotal: number;
  taxTotal: number;
  discountTotal: number;
  grandTotal: number;
  paymentMethod: string;
  paymentAmount: number;
  splitPayments?: { method: string, amount: number }[]; // For split payments
}

export async function placeOrder(payload: PlaceOrderPayload) {
  const supabase = await createClient()
  
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')
    
  const { data: profile } = await supabase.from('profiles').select('tenant_id, outlet_id, id').eq('id', user.id).single()
  if (!profile?.tenant_id) throw new Error('No tenant associated with user')

  const outlet_id = profile.outlet_id;
  if (!outlet_id) throw new Error('No outlet assigned to user')

  // Generate an order number (e.g., ORD-YYYYMMDD-XXXX)
  const dateStr = new Date().toISOString().split('T')[0].replace(/-/g, '');
  const randNum = Math.floor(1000 + Math.random() * 9000);
  const orderNumber = `ORD-${dateStr}-${randNum}`;
  const invoiceNumber = `INV-${dateStr}-${randNum}`; // GST Invoice Number

  // 1. Insert Order
  const { data: order, error: orderError } = await supabase
    .from('orders')
    .insert({
      tenant_id: profile.tenant_id,
      outlet_id,
      user_id: profile.id,
      customer_id: payload.customerId,
      order_number: orderNumber,
      invoice_number: invoiceNumber,
      order_type: payload.orderType,
      status: 'COMPLETED',
      payment_status: 'PAID',
      subtotal: payload.subtotal,
      tax_total: payload.taxTotal,
      discount_total: payload.discountTotal,
      grand_total: payload.grandTotal,
      inventory_processed: true
    })
    .select()
    .single();

  if (orderError) throw new Error(`Order Creation Failed: ${orderError.message}`);

  // 2. Insert Order Items
  const orderItems = payload.items.map(item => ({
    tenant_id: profile.tenant_id,
    order_id: order.id,
    menu_item_id: item.id,
    quantity: item.quantity,
    unit_price: item.price,
    subtotal: item.price * item.quantity,
    tax_amount: item.tax_amount || 0,
    discount_amount: item.discount_amount || 0,
    total_price: (item.price * item.quantity) + (item.tax_amount || 0) - (item.discount_amount || 0),
    status: 'SERVED'
  }));

  const { error: itemsError } = await supabase.from('order_items').insert(orderItems);
  if (itemsError) throw new Error(`Order Items Creation Failed: ${itemsError.message}`);

  // 3. Insert Payments
  const payments = [];
  if (payload.splitPayments && payload.splitPayments.length > 0) {
    payload.splitPayments.forEach(p => {
      payments.push({
        tenant_id: profile.tenant_id,
        outlet_id,
        order_id: order.id,
        customer_id: payload.customerId,
        amount: p.amount,
        payment_method: p.method,
        status: 'COMPLETED'
      })
    })
  } else {
    payments.push({
      tenant_id: profile.tenant_id,
      outlet_id,
      order_id: order.id,
      customer_id: payload.customerId,
      amount: payload.paymentAmount,
      payment_method: payload.paymentMethod,
      status: 'COMPLETED'
    })
  }
  
  const { error: paymentError } = await supabase.from('payments').insert(payments);
  if (paymentError) throw new Error(`Payment Creation Failed: ${paymentError.message}`);

  // 4. Synchronous Inventory Deduction
  // Fetch recipes for the ordered items
  const menuItemIds = payload.items.map(i => i.id);
  const { data: recipes } = await supabase
    .from('recipes')
    .select('id, menu_item_id')
    .in('menu_item_id', menuItemIds)
    .eq('status', 'ACTIVE');
    
  if (recipes && recipes.length > 0) {
    const recipeIds = recipes.map(r => r.id);
    const { data: recipeItems } = await supabase
      .from('recipe_items')
      .select('recipe_id, inventory_item_id, quantity')
      .in('recipe_id', recipeIds);
      
    if (recipeItems && recipeItems.length > 0) {
      // Map menu items to required inventory changes
      const inventoryAdjustments: Record<string, number> = {};
      
      payload.items.forEach(orderItem => {
        const recipe = recipes.find(r => r.menu_item_id === orderItem.id);
        if (recipe) {
          const ingredients = recipeItems.filter(ri => ri.recipe_id === recipe.id);
          ingredients.forEach(ing => {
            const totalQtyNeeded = ing.quantity * orderItem.quantity;
            if (!inventoryAdjustments[ing.inventory_item_id]) {
              inventoryAdjustments[ing.inventory_item_id] = 0;
            }
            inventoryAdjustments[ing.inventory_item_id] += totalQtyNeeded;
          });
        }
      });
      
      const txs = Object.entries(inventoryAdjustments).map(([inventory_item_id, quantity]) => ({
        tenant_id: profile.tenant_id,
        outlet_id: outlet_id,
        inventory_item_id,
        transaction_type: 'SALE',
        quantity_change: -quantity, // Deduction
        unit_cost: 0, // In a real system, we might query the moving average cost here.
        reference_type: 'ORDER',
        reference_id: order.id,
        notes: `Auto-deduction for order ${order.order_number}`,
        created_by: profile.id
      }));

      if (txs.length > 0) {
        await supabase.from('inventory_transactions').insert(txs);
      }
    }
  }

  return { success: true, orderId: order.id, orderNumber: order.order_number, invoiceNumber: order.invoice_number };
}
