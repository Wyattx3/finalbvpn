"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Lock, Mail, ArrowRight, ShieldCheck } from "lucide-react";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  // Redirect if already logged in
  useEffect(() => {
    const hasAuthToken = document.cookie.split(';').some((item) => item.trim().startsWith('auth_token='));
    if (hasAuthToken) {
      router.push('/dashboard');
    }
  }, [router]);

  // Helper to parse User Agent - IMPROVED detection
  const getBrowserInfo = () => {
    const ua = navigator.userAgent;
    let browser = "Unknown Browser";
    let os = "Unknown OS";

    // Detect Browser (order matters!)
    if (ua.indexOf("Edg") > -1) {
      browser = "Edge";
    } else if (ua.indexOf("OPR") > -1 || ua.indexOf("Opera") > -1) {
      browser = "Opera";
    } else if (ua.indexOf("Firefox") > -1) {
      browser = "Firefox";
    } else if (ua.indexOf("Chrome") > -1) {
      browser = "Chrome";
    } else if (ua.indexOf("Safari") > -1) {
      browser = "Safari";
    } else if (ua.indexOf("MSIE") > -1 || ua.indexOf("Trident/") > -1) {
      browser = "Internet Explorer";
    }

    // Detect OS
    if (ua.indexOf("Android") > -1) os = "Android";
    else if (ua.indexOf("iPhone") > -1 || ua.indexOf("iPad") > -1) os = "iOS";
    else if (ua.indexOf("Win") > -1) os = "Windows";
    else if (ua.indexOf("Mac") > -1) os = "MacOS";
    else if (ua.indexOf("Linux") > -1) os = "Linux";

    return `${os} • ${browser}`;
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError("");

    // Mock Authentication
    setTimeout(async () => {
      if (email === "admin@bvpn.com" && password === "admin123") {
        // Success
        document.cookie = "auth_token=mock_token; path=/";
        
        // Save Login History to Firebase
        try {
          const browserInfo = getBrowserInfo();
          const ua = navigator.userAgent;
          
          // Detect Browser (order matters!)
          let browser = "Unknown";
          if (ua.indexOf("Edg") > -1) browser = "Edge";
          else if (ua.indexOf("OPR") > -1 || ua.indexOf("Opera") > -1) browser = "Opera";
          else if (ua.indexOf("Firefox") > -1) browser = "Firefox";
          else if (ua.indexOf("Chrome") > -1) browser = "Chrome";
          else if (ua.indexOf("Safari") > -1) browser = "Safari";
          else if (ua.indexOf("MSIE") > -1 || ua.indexOf("Trident/") > -1) browser = "IE";
          
          // Detect OS
          let os = "Unknown";
          if (ua.indexOf("Android") > -1) os = "Android";
          else if (ua.indexOf("iPhone") > -1 || ua.indexOf("iPad") > -1) os = "iOS";
          else if (ua.indexOf("Win") > -1) os = "Windows";
          else if (ua.indexOf("Mac") > -1) os = "MacOS";
          else if (ua.indexOf("Linux") > -1) os = "Linux";
          
          // Get IP and location (using free API)
          let ip = "Unknown";
          let location = "Unknown";
          try {
            const ipResponse = await fetch('https://ipapi.co/json/');
            if (ipResponse.ok) {
              const ipData = await ipResponse.json();
              ip = ipData.ip || "Unknown";
              location = `${ipData.city || ''}, ${ipData.country_name || ''}`.replace(/^, |, $/g, '') || "Unknown";
            }
          } catch (ipError) {
            console.log("Could not get IP info");
          }
          
          // Generate unique session ID
          const sessionId = `session_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
          
          // Save session ID to localStorage for tracking
          localStorage.setItem('admin_session_id', sessionId);
          
          // Save to Firebase via API
          await fetch('/api/admin-login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              email,
              device: browserInfo,
              browser,
              os,
              ip,
              location,
              sessionId,
              isActive: true,
            }),
          });
        } catch (error) {
          console.error("Failed to save login history", error);
        }

        router.push("/dashboard");
      } else {
        setError("Invalid email or password");
        setIsLoading(false);
      }
    }, 1000);
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 p-4 dark:bg-gray-900">
      <div className="w-full max-w-md space-y-8 rounded-2xl bg-white p-8 shadow-xl dark:bg-gray-800 dark:shadow-none">
        <div className="text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400">
            <ShieldCheck className="h-8 w-8" />
          </div>
          <h2 className="text-2xl font-bold tracking-tight text-gray-900 dark:text-white">
            Admin Login
          </h2>
          <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">
            Sign in to access Suk Fhyoke dashboard
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleLogin}>
          <div className="space-y-4">
            <div>
              <label htmlFor="email" className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Email Address
              </label>
              <div className="relative">
                <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                  <Mail className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  id="email"
                  name="email"
                  type="email"
                  autoComplete="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="block w-full rounded-lg border border-gray-300 bg-white py-2.5 pl-10 pr-3 text-gray-900 placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                  placeholder="admin@bvpn.com"
                />
              </div>
            </div>

            <div>
              <label htmlFor="password" className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Password
              </label>
              <div className="relative">
                <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                  <Lock className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  id="password"
                  name="password"
                  type="password"
                  autoComplete="current-password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="block w-full rounded-lg border border-gray-300 bg-white py-2.5 pl-10 pr-3 text-gray-900 placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                  placeholder="••••••••"
                />
              </div>
            </div>
          </div>

          {error && (
            <div className="rounded-lg bg-red-50 p-3 text-sm text-red-500 dark:bg-red-900/20 dark:text-red-400">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={isLoading}
            className="flex w-full items-center justify-center gap-2 rounded-lg bg-blue-600 px-4 py-3 text-sm font-semibold text-white transition-colors hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed dark:focus:ring-offset-gray-800"
          >
            {isLoading ? (
              "Signing in..."
            ) : (
              <>
                Sign In <ArrowRight className="h-4 w-4" />
              </>
            )}
          </button>
        </form>
        </div>
    </div>
  );
}
