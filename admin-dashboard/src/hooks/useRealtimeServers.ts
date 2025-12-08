"use client";

import { useState, useEffect } from 'react';
import { db, collection, onSnapshot } from '@/lib/firebase';

export interface V2RayServer {
  id: string;
  name: string;
  flag: string;
  address: string;
  port: number;
  uuid: string;
  alterId: number;
  security: "auto" | "none" | "aes-128-gcm" | "chacha20-poly1305";
  network: "tcp" | "ws" | "grpc" | "h2";
  path: string;
  tls: boolean;
  country: string;
  load: number;
  status: "online" | "offline" | "maintenance";
  bandwidthUsed?: number;
  totalConnections?: number;
}

export function useRealtimeServers() {
  const [servers, setServers] = useState<V2RayServer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setIsLoading(true);
    
    // Real-time listener for servers collection
    const serversRef = collection(db, 'servers');
    // No orderBy to avoid index issues - sort client-side if needed
    
    const unsubscribe = onSnapshot(
      serversRef,
      (snapshot) => {
        const serversList: V2RayServer[] = [];
        
        snapshot.forEach((doc) => {
          const data = doc.data();
          
          serversList.push({
            id: doc.id,
            name: data.name || 'Unknown Server',
            flag: data.flag || '🏳️',
            address: data.address || '',
            port: data.port || 443,
            uuid: data.uuid || '',
            alterId: data.alterId || 0,
            security: data.security || 'auto',
            network: data.network || 'ws',
            path: data.path || '/',
            tls: data.tls || false,
            country: data.country || 'Unknown',
            load: data.load || 0,
            status: data.status || 'offline',
            bandwidthUsed: data.bandwidthUsed || 0,
            totalConnections: data.totalConnections || 0,
          });
        });
        
        setServers(serversList);
        setIsLoading(false);
        setError(null);
        
        console.log('🔄 Servers real-time update: ', serversList.length, 'servers');
      },
      (err) => {
        console.error('Servers real-time listener error:', err);
        setError(err.message);
        setIsLoading(false);
      }
    );

    // Cleanup listener on unmount
    return () => unsubscribe();
  }, []);

  return { servers, isLoading, error };
}

