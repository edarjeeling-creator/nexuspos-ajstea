import { posDb } from '../db/pos-db';
import { createClient } from '@/utils/supabase/client';

const MAX_RETRIES = 5;
const BASE_BACKOFF_MS = 1000; // 1 second

export class SyncEngine {
  private isSyncing = false;
  private supabase = createClient();

  async flushEvents() {
    if (this.isSyncing || typeof navigator !== 'undefined' && !navigator.onLine) return;
    this.isSyncing = true;

    try {
      // 1. Fetch pending events
      const pendingEvents = await posDb.outbox_events
        .where('sync_status')
        .anyOf('PENDING', 'ERROR')
        .toArray();

      if (pendingEvents.length === 0) {
        this.isSyncing = false;
        return;
      }

      // Filter events that have exceeded max retries to avoid infinite loops,
      // and apply exponential backoff.
      const now = Date.now();
      const eventsToSync = pendingEvents.filter(event => {
        if (event.sync_attempts >= MAX_RETRIES) return false; // Dead letter queue
        
        if (event.sync_status === 'ERROR') {
          // Simplistic backoff check based on creation time for POC
          // In production, we'd add `last_attempt_at` to the schema.
          const backoffDuration = BASE_BACKOFF_MS * Math.pow(2, event.sync_attempts);
          const timeSinceCreation = now - new Date(event.created_at).getTime();
          if (timeSinceCreation < backoffDuration) return false;
        }
        return true;
      });

      if (eventsToSync.length === 0) {
         this.isSyncing = false;
         return;
      }

      // 2. Prepare payload for Supabase
      const payload = eventsToSync.map(e => ({
        id: e.id,
        tenant_id: e.tenant_id,
        outlet_id: e.outlet_id,
        order_id: e.order_id,
        event_type: e.event_type,
        payload: e.payload,
        device_identifier: e.device_identifier,
        created_at: e.created_at
      }));

      // 3. Push to Supabase ledger
      const { error } = await this.supabase.from('order_events').insert(payload);

      // 4. Handle response
      if (error) {
        // If unique constraint violation (code 23505), it was already synced (Idempotency saved us).
        const isDuplicate = error.code === '23505';

        await posDb.transaction('rw', posDb.outbox_events, async () => {
          for (const e of eventsToSync) {
             if (isDuplicate) {
                 await posDb.outbox_events.update(e.id, { sync_status: 'SYNCED' });
             } else {
                 await posDb.outbox_events.update(e.id, {
                   sync_status: 'ERROR',
                   sync_attempts: e.sync_attempts + 1,
                   last_sync_error: error.message
                 });
             }
          }
        });
      } else {
        // Success!
        await posDb.transaction('rw', posDb.outbox_events, async () => {
          for (const e of eventsToSync) {
            await posDb.outbox_events.update(e.id, {
              sync_status: 'SYNCED',
            });
          }
        });
      }

    } catch (err) {
      console.error('Fatal sync engine error:', err);
    } finally {
      this.isSyncing = false;
    }
  }

  startBackgroundSync() {
    if (typeof window === 'undefined') return;
    
    // Poll every 5 seconds
    setInterval(() => this.flushEvents(), 5000);
    
    // Also try flushing immediately when coming online
    window.addEventListener('online', () => this.flushEvents());
  }
}

export const syncEngine = new SyncEngine();
