import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

// Mock representation of @upstash/redis and @upstash/ratelimit
// import { Redis } from '@upstash/redis'
// import { Ratelimit } from '@upstash/ratelimit'

// Initialize Upstash Redis (Mock)
// const redis = new Redis({
//   url: process.env.UPSTASH_REDIS_REST_URL!,
//   token: process.env.UPSTASH_REDIS_REST_TOKEN!,
// })

// Initialize Rate Limiting (Mock: 100 requests per 10 seconds per IP/Key)
// const ratelimit = new Ratelimit({
//   redis: redis,
//   limiter: Ratelimit.slidingWindow(100, '10 s'),
// })

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // 1. API GATEWAY: Only protect /api/v1 routes
  if (pathname.startsWith('/api/v1')) {
    
    // Extract API Key from headers
    const apiKey = request.headers.get('x-api-key') || request.headers.get('Authorization')?.replace('Bearer ', '')
    
    if (!apiKey) {
      // In a real system, we might also log this to integration_logs via a lightweight edge call
      return NextResponse.json({ error: 'Unauthorized: Missing API Key' }, { status: 401 })
    }

    // 2. RATE LIMITING (Mock Implementation)
    // const ip = request.ip ?? '127.0.0.1'
    // const { success, pending, limit, reset, remaining } = await ratelimit.limit(`ratelimit_${apiKey}_${ip}`)
    //
    // if (!success) {
    //   return NextResponse.json({ error: 'Too Many Requests' }, { 
    //     status: 429,
    //     headers: {
    //       'X-RateLimit-Limit': limit.toString(),
    //       'X-RateLimit-Remaining': remaining.toString(),
    //       'X-RateLimit-Reset': reset.toString(),
    //     }
    //   })
    // }

    // 3. API KEY VALIDATION (Mock DB call)
    // Normally we'd hash the key and check against public.api_keys
    // For performance, keys are often cached in Redis.

    const response = NextResponse.next()
    
    // Pass the rate limit headers down to the client
    response.headers.set('X-RateLimit-Limit', '100')
    response.headers.set('X-RateLimit-Remaining', '99')
    
    return response
  }

  return NextResponse.next()
}

// See "Matching Paths" below to learn more
export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
}
