"use client";

import { useState, useEffect } from 'react';
import { db, collection, onSnapshot, query, orderBy, limit } from '@/lib/firebase';

export interface LoginActivity {
  id: string;
  deviceId: string;
  deviceModel: string;
  platform: string;
  ipAddress: string;
  country: string;
  city: string;
  flag: string;
  timestamp: Date;
  type: string;
}

export function useRealtimeLoginActivity(maxItems: number = 20) {
  const [activities, setActivities] = useState<LoginActivity[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    setIsLoading(true);
    
    // Real-time listener for login_activity collection
    const activityRef = collection(db, 'login_activity');
    const q = query(activityRef, orderBy('timestamp', 'desc'), limit(maxItems));
    
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const activityList: LoginActivity[] = [];
        
        snapshot.forEach((doc) => {
          const data = doc.data();
          activityList.push({
            id: doc.id,
            deviceId: data.deviceId || '',
            deviceModel: data.deviceModel || 'Unknown Device',
            platform: data.platform || 'unknown',
            ipAddress: data.ipAddress || '-',
            country: data.country || 'Unknown',
            city: data.city || '',
            flag: data.flag || '🏳️',
            timestamp: data.timestamp?.toDate() || new Date(),
            type: data.type || 'app_open',
          });
        });
        
        setActivities(activityList);
        setIsLoading(false);
        
        console.log('🔐 Real-time login activity update:', activityList.length, 'entries');
      },
      (err) => {
        console.error('Login activity listener error:', err);
        setIsLoading(false);
      }
    );

    return () => unsubscribe();
  }, [maxItems]);

  return { activities, isLoading };
}

