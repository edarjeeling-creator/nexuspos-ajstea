'use client'

import { useLiveQuery } from 'dexie-react-hooks';
import { posDb } from '@/lib/db/pos-db';
import { Cloud, CloudOff, AlertCircle } from 'lucide-react';
import { useEffect, useState } from 'react';

export function SyncStatusIndicator() {
  const [isOnline, setIsOnline] = useState(true);
  
  const pendingCount = useLiveQuery(
    () => posDb.outbox_events.where('sync_status').equals('PENDING').count()
  ) || 0;

  const errorCount = useLiveQuery(
    () => posDb.outbox_events.where('sync_status').equals('ERROR').count()
  ) || 0;

  useEffect(() => {
    setIsOnline(navigator.onLine);
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  if (!isOnline) {
    return (
      <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-500 text-xs font-medium">
        <CloudOff className="h-4 w-4" />
        Offline Mode
      </div>
    );
  }

  if (errorCount > 0) {
    return (
      <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400 text-xs font-medium">
        <AlertCircle className="h-4 w-4" />
        {errorCount} Sync Errors
      </div>
    );
  }

  if (pendingCount > 0) {
    return (
      <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400 text-xs font-medium">
        <Cloud className="h-4 w-4 animate-pulse" />
        Syncing {pendingCount}
      </div>
    );
  }

  return (
    <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 text-xs font-medium">
      <Cloud className="h-4 w-4" />
      Synced
    </div>
  );
}
