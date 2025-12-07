"use client";

import { useState, useEffect } from 'react';
import { db, collection, onSnapshot, query, orderBy, limit } from '@/lib/firebase';

export interface AdminLoginActivity {
  id: string;
  email: string;
  device: string;
  browser: string;
  os: string;
  ip: string;
  location: string;
  timestamp: Date;
  lastActivity: Date;
  isActive: boolean;
  sessionId: string | null;
  type: string;
}

export function useAdminLoginActivity(maxItems: number = 100) {
  const [activities, setActivities] = useState<AdminLoginActivity[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeCount, setActiveCount] = useState(0);

  useEffect(() => {
    setIsLoading(true);
    
    // Real-time listener for admin_login_activity collection
    const activityRef = collection(db, 'admin_login_activity');
    const q = query(activityRef, orderBy('timestamp', 'desc'), limit(maxItems));
    
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const activityList: AdminLoginActivity[] = [];
        let active = 0;
        const now = new Date();
        
        snapshot.forEach((doc) => {
          const data = doc.data();
          const lastActivity = data.lastActivity?.toDate() || data.timestamp?.toDate() || new Date();
          
          // Consider session active if last activity was within 5 minutes
          const isRecentlyActive = (now.getTime() - lastActivity.getTime()) < 5 * 60 * 1000;
          const isActive = data.isActive && isRecentlyActive;
          
          if (isActive) active++;
          
          activityList.push({
            id: doc.id,
            email: data.email || 'admin@bvpn.com',
            device: data.device || 'Unknown Device',
            browser: data.browser || 'Unknown',
            os: data.os || 'Unknown',
            ip: data.ip || '-',
            location: data.location || 'Unknown',
            timestamp: data.timestamp?.toDate() || new Date(),
            lastActivity: lastActivity,
            isActive: isActive,
            sessionId: data.sessionId || null,
            type: data.type || 'login',
          });
        });
        
        setActivities(activityList);
        setActiveCount(active);
        setIsLoading(false);
        
        console.log('🔐 Real-time admin login activity update:', activityList.length, 'entries,', active, 'active');
      },
      (err) => {
        console.error('Admin login activity listener error:', err);
        setIsLoading(false);
      }
    );

    return () => unsubscribe();
  }, [maxItems]);

  return { activities, isLoading, activeCount };
}

// Hook for session heartbeat
export function useSessionHeartbeat() {
  useEffect(() => {
    const sessionId = localStorage.getItem('admin_session_id');
    if (!sessionId) return;

    // Send heartbeat every 2 minutes
    const heartbeat = async () => {
      try {
        await fetch('/api/admin-login', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ sessionId }),
        });
      } catch (e) {
        console.error('Heartbeat failed:', e);
      }
    };

    // Initial heartbeat
    heartbeat();

    // Set interval
    const interval = setInterval(heartbeat, 2 * 60 * 1000); // Every 2 minutes

    // Cleanup on logout or page close - use Blob for proper JSON content type
    const handleBeforeUnload = () => {
      // Use Blob to send JSON with correct content type via sendBeacon
      const data = new Blob(
        [JSON.stringify({ sessionId, action: 'logout' })],
        { type: 'application/json' }
      );
      navigator.sendBeacon('/api/admin-login/logout', data);
    };

    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
      clearInterval(interval);
      window.removeEventListener('beforeunload', handleBeforeUnload);
    };
  }, []);
}

