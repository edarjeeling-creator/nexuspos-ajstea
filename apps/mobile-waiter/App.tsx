import { useState, useEffect } from 'react';
import { View, Text, Button, Alert, FlatList } from 'react-native';
import * as SQLite from 'expo-sqlite';
import * as Notifications from 'expo-notifications';

// 1. OFFLINE ARCHITECTURE: EXPO SQLITE
// Open local database synchronously for maximum performance
const db = SQLite.openDatabase('nexuspos_waiter.db');

export default function WaiterApp() {
  const [tables, setTables] = useState([]);
  const [expoPushToken, setExpoPushToken] = useState('');

  useEffect(() => {
    // Initialize Local Schema (SyncEngine relies on this)
    db.transaction(tx => {
      tx.executeSql(`
        CREATE TABLE IF NOT EXISTS outbox_events (
          id TEXT PRIMARY KEY,
          event_type TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        );
      `);
      tx.executeSql(`
        CREATE TABLE IF NOT EXISTS local_tables (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          status TEXT NOT NULL
        );
      `);
    });

    // Register Push Notifications
    registerForPushNotificationsAsync().then(token => {
      setExpoPushToken(token);
      // In reality, we'd sync this token to public.mobile_devices
    });

    fetchLocalTables();
  }, []);

  const fetchLocalTables = () => {
    db.transaction(tx => {
      tx.executeSql('SELECT * FROM local_tables', [], (_, { rows: { _array } }) => {
        setTables(_array);
      });
    });
  };

  // 2. OFFLINE QUEUE WORKFLOW
  const submitOrderOffline = (tableId: string, payload: any) => {
    const eventId = Math.random().toString(36).substring(7); // Mock UUID
    db.transaction(tx => {
      tx.executeSql(
        'INSERT INTO outbox_events (id, event_type, payload, created_at) VALUES (?, ?, ?, ?)',
        [eventId, 'ORDER_CREATED', JSON.stringify(payload), new Date().toISOString()],
        () => {
          Alert.alert('Order Saved', 'Order saved locally. Will sync when online.');
          // SyncEngine.trigger() would be called here to push to Supabase
        },
        (_, error) => {
          Alert.alert('Error', 'Failed to save order locally.');
          return false;
        }
      );
    });
  };

  // 3. TABLE WORKFLOWS (Merge/Split/Transfer)
  const transferTable = (sourceTableId: string, targetTableId: string) => {
    const eventId = Math.random().toString(36).substring(7);
    db.transaction(tx => {
      tx.executeSql(
        'INSERT INTO outbox_events (id, event_type, payload, created_at) VALUES (?, ?, ?, ?)',
        [eventId, 'TABLE_TRANSFERRED', JSON.stringify({ sourceTableId, targetTableId }), new Date().toISOString()],
        () => Alert.alert('Success', 'Table transfer event queued.')
      );
    });
  };

  return (
    <View style={{ flex: 1, padding: 40, backgroundColor: '#f8fafc' }}>
      <Text style={{ fontSize: 24, fontWeight: 'bold', marginBottom: 20 }}>Waiter App (Offline Mode)</Text>
      
      <View style={{ marginBottom: 20, padding: 15, backgroundColor: '#e2e8f0', borderRadius: 8 }}>
        <Text style={{ fontWeight: 'bold' }}>Push Token:</Text>
        <Text style={{ fontSize: 10 }}>{expoPushToken || 'Loading...'}</Text>
      </View>

      <Button 
        title="Simulate Offline Order" 
        onPress={() => submitOrderOffline('table_1', { items: [{ id: 'burger_1', qty: 2 }] })} 
      />

      <View style={{ height: 10 }} />

      <Button 
        title="Simulate Table Transfer (T1 -> T2)" 
        onPress={() => transferTable('table_1', 'table_2')} 
        color="#f59e0b"
      />

      <Text style={{ marginTop: 30, fontSize: 18, fontWeight: 'bold' }}>Local Tables Cache</Text>
      <FlatList
        data={tables}
        keyExtractor={item => item.id}
        renderItem={({ item }) => (
          <View style={{ padding: 15, borderBottomWidth: 1, borderColor: '#cbd5e1' }}>
            <Text>{item.name} - {item.status}</Text>
          </View>
        )}
        ListEmptyComponent={<Text style={{ marginTop: 10, color: '#64748b' }}>No tables synced to local device yet.</Text>}
      />
    </View>
  );
}

// Helper: Push Notifications
async function registerForPushNotificationsAsync() {
  let token = '';
  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;
  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }
  if (finalStatus !== 'granted') {
    return '';
  }
  token = (await Notifications.getExpoPushTokenAsync()).data;
  return token;
}
