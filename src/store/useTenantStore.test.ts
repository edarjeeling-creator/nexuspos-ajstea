import { describe, it, expect, beforeEach } from 'vitest'
import { useTenantStore } from './useTenantStore'

describe('useTenantStore', () => {
  beforeEach(() => {
    useTenantStore.getState().clearTenant()
  })

  it('should initialize with null values', () => {
    const state = useTenantStore.getState()
    expect(state.tenantId).toBeNull()
    expect(state.outletId).toBeNull()
    expect(state.permissions).toEqual([])
  })

  it('should set tenant data correctly', () => {
    useTenantStore.getState().setTenant('t1', 'o1', ['pos.*'])
    const state = useTenantStore.getState()
    expect(state.tenantId).toBe('t1')
    expect(state.outletId).toBe('o1')
    expect(state.permissions).toEqual(['pos.*'])
  })
})
