"use client";

import { useState, useEffect } from 'react';
import { db, collection, onSnapshot, query, orderBy } from '@/lib/firebase';

export interface RealtimeDevice {
  id: string;
  deviceModel: string;
  ipAddress: string;
  country: string;
  flag: string;
  balance: number;
  status: "online" | "offline" | "banned" | "vpn_connected";
  dataUsage: number;
  lastSeen: string;
  appVersion: string;
  todayEarnings?: number;
  adsWatchedToday?: number;
  vpnRemainingSeconds?: number; // VPN connection time remaining
}

// 5 minutes timeout for "online" status
const ONLINE_TIMEOUT_MS = 5 * 60 * 1000;

// Calculate online status based on lastSeen timestamp and stored status
function calculateOnlineStatus(lastSeen: Date | null, storedStatus: string): "online" | "offline" | "banned" | "vpn_connected" {
  // If banned, keep as banned
  if (storedStatus === 'banned') {
    return 'banned';
  }
  
  // If VPN connected, show as vpn_connected (takes priority)
  if (storedStatus === 'vpn_connected') {
    // But still check if it's stale
    if (lastSeen) {
      const now = new Date();
      const timeDiff = now.getTime() - lastSeen.getTime();
      if (timeDiff <= ONLINE_TIMEOUT_MS) {
        return 'vpn_connected';
      }
    }
    return 'offline';
  }
  
  if (!lastSeen) {
    return 'offline';
  }
  
  const now = new Date();
  const timeDiff = now.getTime() - lastSeen.getTime();
  
  // If last seen within 5 minutes, consider online
  if (timeDiff <= ONLINE_TIMEOUT_MS) {
    return storedStatus === 'online' ? 'online' : 'offline';
  }
  
  return 'offline';
}

export function useRealtimeDevices() {
  const [devices, setDevices] = useState<RealtimeDevice[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setIsLoading(true);
    
    // Real-time listener for devices collection
    const devicesRef = collection(db, 'devices');
    const q = query(devicesRef, orderBy('lastSeen', 'desc'));
    
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const devicesList: RealtimeDevice[] = [];
        
        snapshot.forEach((doc) => {
          const data = doc.data();
          const lastSeenDate = data.lastSeen?.toDate?.() || null;
          const calculatedStatus = calculateOnlineStatus(lastSeenDate, data.status || 'offline');
          
          devicesList.push({
            id: doc.id,
            deviceModel: data.deviceModel || 'Unknown Device',
            ipAddress: data.ipAddress || '-',
            country: data.country || 'Unknown',
            flag: data.flag || '🏳️',
            balance: data.balance || 0,
            status: calculatedStatus,
            dataUsage: data.dataUsage || 0,
            lastSeen: lastSeenDate?.toISOString() || new Date().toISOString(),
            appVersion: data.appVersion || 'v1.0.0',
            todayEarnings: data.todayEarnings || 0,
            adsWatchedToday: data.adsWatchedToday || 0,
            vpnRemainingSeconds: data.vpnRemainingSeconds || 0,
          });
        });
        
        setDevices(devicesList);
        setIsLoading(false);
        setError(null);
        
        console.log('🔄 Real-time update: ', devicesList.length, 'devices');
      },
      (err) => {
        console.error('Real-time listener error:', err);
        setError(err.message);
        setIsLoading(false);
      }
    );

    // Refresh status calculation every minute
    const statusRefreshInterval = setInterval(() => {
      setDevices(prevDevices => {
        return prevDevices.map(device => ({
          ...device,
          status: calculateOnlineStatus(
            device.lastSeen ? new Date(device.lastSeen) : null,
            device.status === 'banned' ? 'banned' : device.status
          ),
        }));
      });
    }, 60 * 1000); // Every 1 minute

    // Cleanup listener on unmount
    return () => {
      unsubscribe();
      clearInterval(statusRefreshInterval);
    };
  }, []);

  return { devices, isLoading, error };
}

