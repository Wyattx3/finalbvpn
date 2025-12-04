import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

// List of protected routes that require authentication
const protectedRoutes = ['/dashboard', '/users', '/servers', '/withdrawals', '/sdui', '/settings']

// Check if the path starts with any protected route
function isProtectedRoute(pathname: string): boolean {
  return protectedRoutes.some(route => pathname === route || pathname.startsWith(`${route}/`))
}

export function middleware(request: NextRequest) {
  const authToken = request.cookies.get('auth_token')?.value
  const { pathname } = request.nextUrl

  console.log(`[Middleware] Path: ${pathname} | Auth: ${!!authToken}`)

  // Root path '/' is the Login Page (Public)
  if (pathname === '/') {
    if (authToken) {
      // Already logged in, redirect to dashboard
      console.log('[Middleware] Authenticated user on login, redirecting to /dashboard')
      return NextResponse.redirect(new URL('/dashboard', request.url))
    }
    // Allow access to login page
    return NextResponse.next()
  }

  // For ALL other routes (protected or not), require authentication
  if (!authToken) {
    console.log('[Middleware] Unauthenticated access attempt, redirecting to /')
    return NextResponse.redirect(new URL('/', request.url))
  }

  // User is authenticated, allow access
  return NextResponse.next()
}

export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - api (API routes)
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico, sitemap.xml, robots.txt (metadata files)
     * - Public assets (svg, png, jpg, etc.)
     */
    '/((?!api|_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
