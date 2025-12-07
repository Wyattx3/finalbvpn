import { NextResponse } from 'next/server';
import { getDashboardStats } from '@/lib/firebase-admin';

export async function GET() {
  try {
    const stats = await getDashboardStats();
    return NextResponse.json({ success: true, stats });
  } catch (error) {
    console.error('Error fetching stats:', error);
    return NextResponse.json({ success: false, error: 'Failed to fetch stats' }, { status: 500 });
  }
}

