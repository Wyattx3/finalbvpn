"use client";

import { Geist, Geist_Mono } from "next/font/google";
import Sidebar from "@/components/Sidebar";
import { ThemeProvider } from "@/components/theme-provider";
import SessionTimeoutHandler from "@/components/SessionTimeoutHandler";
import { usePathname } from "next/navigation";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// Routes that should show the sidebar (authenticated dashboard routes)
const dashboardRoutes = ['/dashboard', '/users', '/servers', '/withdrawals', '/sdui', '/settings'];

function isDashboardRoute(pathname: string): boolean {
  return dashboardRoutes.some(route => pathname === route || pathname.startsWith(`${route}/`));
}

// Inline script to prevent flash of wrong theme
const themeScript = `
  (function() {
    const storageKey = 'bvpn-admin-theme';
    let theme;
    try {
      theme = localStorage.getItem(storageKey);
    } catch {}
    
    if (!theme || !['dark', 'light', 'system'].includes(theme)) {
      theme = 'system';
    }
    
    let resolvedTheme = theme;
    if (theme === 'system') {
      resolvedTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    
    document.documentElement.classList.add(resolvedTheme);
  })();
`;

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const pathname = usePathname();
  // Only show sidebar on known dashboard routes
  const showSidebar = isDashboardRoute(pathname);

  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-gray-50 text-gray-900 dark:bg-gray-900 dark:text-gray-100`}
      >
        <ThemeProvider defaultTheme="system" storageKey="bvpn-admin-theme">
          <div className="flex min-h-screen">
            <SessionTimeoutHandler />
            {showSidebar && <Sidebar />}
            <main className={`flex-1 overflow-auto ${showSidebar ? 'ml-64 p-8' : ''}`}>
              {children}
            </main>
          </div>
        </ThemeProvider>
      </body>
    </html>
  );
}
