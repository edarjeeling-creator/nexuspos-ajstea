export const MODULES = [
  'pos',
  'inventory',
  'crm',
  'hrms',
  'erp',
  'accounting',
  'analytics',
  'notifications',
  'integrations',
  'settings',
  'shift',
  'cash'
] as const;

export type Module = typeof MODULES[number];

export const ACTIONS = [
  'create',
  'read',
  'update',
  'delete',
  'approve',
  'void',
  'export',
  'manage',
  'open',
  'close',
  'override',
  'view',
  'adjust',
  'drop',
  'audit'
] as const;

export type Action = typeof ACTIONS[number];

export type Permission = `${Module}.${Action}` | '*';
