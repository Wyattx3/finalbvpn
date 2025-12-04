"use client";

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";

export default function SessionTimeoutHandler() {
  const router = useRouter();
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  // Reset timer on user activity
  const resetTimer = () => {
    if (timerRef.current) clearTimeout(timerRef.current);

    // Get timeout setting from localStorage (default 30 mins)
    let timeoutMinutes = 30;
    try {
      const storedPrefs = localStorage.getItem('admin_preferences');
      if (storedPrefs) {
        const prefs = JSON.parse(storedPrefs);
        if (prefs.autoLogout) {
          timeoutMinutes = parseInt(prefs.autoLogout);
        }
      }
    } catch (e) {}

    const timeoutMs = timeoutMinutes * 60 * 1000;

    timerRef.current = setTimeout(() => {
      handleLogout();
    }, timeoutMs);
  };

  const handleLogout = () => {
    // Check if we are logged in
    const hasAuthToken = document.cookie.split(';').some((item) => item.trim().startsWith('auth_token='));
    
    if (hasAuthToken) {
      console.log("Session timed out due to inactivity.");
      // Clear cookie
      document.cookie = "auth_token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT";
      // Redirect
      window.location.href = "/"; // Force full reload to clear states
    }
  };

  useEffect(() => {
    // Initial timer
    resetTimer();

    // Events to listen for
    const events = ["mousedown", "keypress", "scroll", "touchstart"];

    const handleActivity = () => {
      resetTimer();
    };

    // Add listeners
    events.forEach((event) => {
      window.addEventListener(event, handleActivity);
    });

    // Cleanup
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
      events.forEach((event) => {
        window.removeEventListener(event, handleActivity);
      });
    };
  }, []);

  return null; // This component renders nothing
}

