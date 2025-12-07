"use client";

import { useState, useEffect } from 'react';
import { db, collection, onSnapshot, query } from '@/lib/firebase';

export interface RealtimeStats {
  totalUsers: number;
  totalBalance: number;
  totalAdsWatched: number;
  totalEarnings: number;
  onlineUsers: number;
  bannedUsers: number;
}

export function useRealtimeStats() {
  const [stats, setStats] = useState<RealtimeStats>({
    totalUsers: 0,
    totalBalance: 0,
    totalAdsWatched: 0,
    totalEarnings: 0,
    onlineUsers: 0,
    bannedUsers: 0,
  });
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    setIsLoading(true);
    
    // Real-time listener for devices collection
    const devicesRef = collection(db, 'devices');
    
    const unsubscribe = onSnapshot(
      devicesRef,
      (snapshot) => {
        let totalBalance = 0;
        let totalAdsWatched = 0;
        let totalEarnings = 0;
        let onlineUsers = 0;
        let bannedUsers = 0;
        
        snapshot.forEach((doc) => {
          const data = doc.data();
          totalBalance += data.balance || 0;
          totalAdsWatched += data.adsWatchedToday || 0;
          totalEarnings += data.todayEarnings || 0;
          
          if (data.status === 'online') onlineUsers++;
          if (data.status === 'banned') bannedUsers++;
        });
        
        setStats({
          totalUsers: snapshot.size,
          totalBalance,
          totalAdsWatched,
          totalEarnings,
          onlineUsers,
          bannedUsers,
        });
        
        setIsLoading(false);
        console.log('📊 Real-time stats update:', snapshot.size, 'users');
      },
      (err) => {
        console.error('Stats listener error:', err);
        setIsLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  return { stats, isLoading };
}

export function useRealtimeWithdrawals() {
  const [withdrawals, setWithdrawals] = useState<any[]>([]);
  const [pendingCount, setPendingCount] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const withdrawalsRef = collection(db, 'withdrawals');
    const q = query(withdrawalsRef);
    
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const list: any[] = [];
        let pending = 0;
        
        snapshot.forEach((doc) => {
          const data = doc.data();
          list.push({ id: doc.id, ...data });
          if (data.status === 'pending') pending++;
        });
        
        setWithdrawals(list);
        setPendingCount(pending);
        setIsLoading(false);
        
        console.log('💰 Real-time withdrawals update:', list.length);
      },
      (err) => {
        console.error('Withdrawals listener error:', err);
        setIsLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  return { withdrawals, pendingCount, isLoading };
}

