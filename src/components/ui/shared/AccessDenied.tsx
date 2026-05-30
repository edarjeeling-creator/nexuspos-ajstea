import { ShieldAlert } from 'lucide-react'
import { Button } from '@/components/ui/button'
import Link from 'next/link'

export default function AccessDenied() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] text-center px-4">
      <div className="h-20 w-20 bg-red-100 dark:bg-red-900/20 rounded-full flex items-center justify-center mb-6">
        <ShieldAlert className="h-10 w-10 text-red-600 dark:text-red-500" />
      </div>
      <h2 className="text-2xl font-bold text-slate-900 dark:text-white mb-2">Access Denied</h2>
      <p className="text-slate-500 dark:text-slate-400 max-w-md mb-8">
        You don't have the necessary permissions to view this module. Please contact your administrator if you believe this is a mistake.
      </p>
      <Button asChild>
        <Link href="/dashboard/overview">Return to Dashboard</Link>
      </Button>
    </div>
  )
}
