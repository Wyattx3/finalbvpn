"use client";

import { useState, useEffect } from 'react';
import { db, collection, onSnapshot, query, orderBy, limit } from '@/lib/firebase';

export interface RealtimeWithdrawal {
  id: string;
  deviceId: string;
  points: number;
  amount: number;
  method: string;
  accountNumber: string;
  accountName: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: string | null;
  processedAt: string | null;
  rejectionReason?: string;
  transactionId?: string;
  receiptUrl?: string;
}

export function useRealtimeWithdrawals() {
  const [withdrawals, setWithdrawals] = useState<RealtimeWithdrawal[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    console.log('🔄 Starting real-time withdrawals listener...');
    
    const q = query(
      collection(db, 'withdrawals'),
      orderBy('createdAt', 'desc'),
      limit(100)
    );

    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const withdrawalsList: RealtimeWithdrawal[] = [];
        snapshot.forEach((doc) => {
          const data = doc.data();
          withdrawalsList.push({
            id: doc.id,
            deviceId: data.deviceId || '',
            points: data.points || 0,
            amount: data.amount || data.points || 0,
            method: data.method || 'Unknown',
            accountNumber: data.accountNumber || '',
            accountName: data.accountName || '',
            status: data.status || 'pending',
            createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
            processedAt: data.processedAt?.toDate?.()?.toISOString() || null,
            rejectionReason: data.rejectionReason,
            transactionId: data.transactionId,
            receiptUrl: data.receiptUrl,
          });
        });
        setWithdrawals(withdrawalsList);
        setIsLoading(false);
        setError(null);
        console.log('💰 Real-time withdrawals update:', withdrawalsList.length, 'items');
      },
      (err) => {
        console.error('Real-time withdrawals error:', err);
        setError(err.message);
        setIsLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  return { withdrawals, isLoading, error };
}

