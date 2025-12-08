import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// Helper to parse Firestore timestamp
function parseTimestamp(timestamp: any): Date | null {
  if (!timestamp) return null;
  if (timestamp.toDate) return timestamp.toDate();
  if (timestamp instanceof Date) return timestamp;
  if (typeof timestamp === 'string') return new Date(timestamp);
  if (typeof timestamp === 'number') return new Date(timestamp);
  return null;
}

// Get chart data based on period
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const period = searchParams.get('period') || 'month';

    // Get actual data from database first
    const devicesSnapshot = await adminDb.collection('devices').get();
    const withdrawalsSnapshot = await adminDb.collection('withdrawals').get();

    // Aggregate data by actual dates from Firebase
    const dataByDate: Map<string, { users: number; withdrawals: number; rewards: number }> = new Map();

    // Process devices
    devicesSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      const createdAt = parseTimestamp(data.createdAt);
      
      if (createdAt) {
        let key: string;
        let displayKey: string;
        
        if (period === 'day') {
          // Group by day: "Dec 4"
          displayKey = `${MONTHS[createdAt.getMonth()]} ${createdAt.getDate()}`;
          key = `${createdAt.getFullYear()}-${String(createdAt.getMonth()+1).padStart(2,'0')}-${String(createdAt.getDate()).padStart(2,'0')}`;
        } else if (period === 'month') {
          // Group by month: "Dec" only
          displayKey = MONTHS[createdAt.getMonth()];
          key = `${createdAt.getFullYear()}-${String(createdAt.getMonth()+1).padStart(2,'0')}`;
        } else {
          // Group by year: "2025"
          displayKey = createdAt.getFullYear().toString();
          key = displayKey;
        }
        
        if (!dataByDate.has(key)) {
          dataByDate.set(key, { users: 0, withdrawals: 0, rewards: 0, displayKey } as any);
        }
        const entry = dataByDate.get(key)!;
        entry.users += 1;
        entry.rewards += data.balance || 0;
        (entry as any).displayKey = displayKey;
        (entry as any).sortKey = key;
      }
    });

    // Process withdrawals - ONLY APPROVED
    withdrawalsSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (data.status !== 'approved') return;
      
      const createdAt = parseTimestamp(data.createdAt);
      const points = data.points || 0;
      
      if (createdAt) {
        let key: string;
        let displayKey: string;
        
        if (period === 'day') {
          displayKey = `${MONTHS[createdAt.getMonth()]} ${createdAt.getDate()}`;
          key = `${createdAt.getFullYear()}-${String(createdAt.getMonth()+1).padStart(2,'0')}-${String(createdAt.getDate()).padStart(2,'0')}`;
        } else if (period === 'month') {
          // Group by month: "Dec" only
          displayKey = MONTHS[createdAt.getMonth()];
          key = `${createdAt.getFullYear()}-${String(createdAt.getMonth()+1).padStart(2,'0')}`;
        } else {
          displayKey = createdAt.getFullYear().toString();
          key = displayKey;
        }
        
        if (!dataByDate.has(key)) {
          dataByDate.set(key, { users: 0, withdrawals: 0, rewards: 0, displayKey } as any);
        }
        const entry = dataByDate.get(key)!;
        entry.withdrawals += points;
        (entry as any).displayKey = displayKey;
        (entry as any).sortKey = key;
      }
    });

    // Convert to array and sort by date
    const results = Array.from(dataByDate.values())
      .sort((a: any, b: any) => a.sortKey.localeCompare(b.sortKey))
      .map((entry: any) => ({
        name: entry.displayKey,
        users: entry.users,
        withdrawals: entry.withdrawals,
        rewards: entry.rewards,
      }));

    return NextResponse.json({
      success: true,
      period,
      data: results,
    });
  } catch (error) {
    console.error('Error fetching analytics:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch analytics', data: [] },
      { status: 500 }
    );
  }
}
