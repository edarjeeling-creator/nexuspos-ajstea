'use client'

import { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Checkbox } from '@/components/ui/checkbox'
import { Button } from '@/components/ui/button'
import { MODULES, ACTIONS, Action, Module } from '@/lib/constants/permissions'
import { RouteGuard } from '@/components/auth/route-guard'

// Mock role for UI building
const MOCK_ROLE = {
  id: '1',
  name: 'MANAGER',
  permissions: ['pos.read', 'pos.create', 'pos.update', 'inventory.read'] as string[]
}

export default function RBACManagementPage() {
  const [activeRole, setActiveRole] = useState(MOCK_ROLE)
  const [saving, setSaving] = useState(false)

  const handleToggle = (module: Module, action: Action) => {
    const permString = `${module}.${action}`
    setActiveRole(prev => {
      const hasPerm = prev.permissions.includes(permString)
      const newPerms = hasPerm 
        ? prev.permissions.filter(p => p !== permString)
        : [...prev.permissions, permString]
      return { ...prev, permissions: newPerms }
    })
  }

  const handleSave = () => {
    setSaving(true)
    setTimeout(() => {
      setSaving(false)
    }, 1000)
  }

  return (
    <RouteGuard module="settings">
      <div className="flex flex-col gap-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">RBAC Management</h1>
            <p className="text-slate-500 dark:text-slate-400 mt-1">
              Configure fine-grained permissions for tenant roles.
            </p>
          </div>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? 'Saving...' : 'Save Changes'}
          </Button>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Role Permissions: {activeRole.name}</CardTitle>
            <CardDescription>
              Select the modules and actions this role can perform.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[150px]">Module</TableHead>
                    {ACTIONS.map(action => (
                      <TableHead key={action} className="text-center capitalize">
                        {action}
                      </TableHead>
                    ))}
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {MODULES.map(module => (
                    <TableRow key={module}>
                      <TableCell className="font-medium capitalize">{module}</TableCell>
                      {ACTIONS.map(action => {
                        const permString = `${module}.${action}`
                        const isChecked = activeRole.permissions.includes(permString)
                        
                        return (
                          <TableCell key={action} className="text-center">
                            <Checkbox 
                              checked={isChecked}
                              onCheckedChange={() => handleToggle(module, action)}
                              aria-label={`Toggle ${action} for ${module}`}
                            />
                          </TableCell>
                        )
                      })}
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </div>
    </RouteGuard>
  )
}
