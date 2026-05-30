import Dexie, { Table } from 'dexie';

export interface PosEvent {
  id: string;
  tenant_id: string;
  outlet_id: string;
  order_id: string;
  event_type: string;
  payload: any;
  device_identifier: string;
  created_at: string;
  sync_status: 'PENDING' | 'SYNCED' | 'ERROR';
  sync_attempts: number;
  last_sync_error?: string;
}

export interface ShiftEvent {
  id: string;
  tenant_id: string;
  outlet_id: string;
  shift_id: string;
  event_type: 'CASH_IN' | 'CASH_OUT' | 'PETTY_CASH' | 'CASH_DROP';
  amount: number;
  reason?: string;
  created_at: string;
  sync_status: 'PENDING' | 'SYNCED' | 'ERROR';
  sync_attempts: number;
}

export interface MenuItem {
  id: string;
  name: string;
  price: number;
  category: string;
  barcode?: string;
  stock_quantity: number;
  is_available: boolean;
}

export interface DraftOrder {
  id: string;
  name: string;
  table_number?: string;
  state: any;
  created_at: string;
  updated_at: string;
}

export class PosDatabase extends Dexie {
  outbox_events!: Table<PosEvent>;
  shift_events!: Table<ShiftEvent>;
  menu_cache!: Table<MenuItem>;
  draft_orders!: Table<DraftOrder>;
  kot_queue!: Table<any>;

  constructor() {
    super('NexusPOS_LocalDB');
    this.version(2).stores({
      outbox_events: 'id, sync_status, order_id, created_at',
      shift_events: 'id, sync_status, shift_id, created_at',
      menu_cache: 'id, category, barcode',
      draft_orders: 'id, name, table_number, updated_at',
      kot_queue: 'id, status, created_at'
    });
  }
}

export const posDb = new PosDatabase();
