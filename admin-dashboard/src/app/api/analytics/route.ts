import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// Get chart data based on period
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const period = searchParams.get('period') || 'month';

    const now = new Date();
    const results: Array<{
      name: string;
      users: number;
      withdrawals: number;
      rewards: number;
    }> = [];

    if (period === 'day') {
      // Last 30 days
      for (let i = 29; i >= 0; i--) {
        const date = new Date(now);
        date.setDate(date.getDate() - i);
        const dayLabel = `Day ${30 - i}`;

        results.push({
          name: dayLabel,
          users: 0,
          withdrawals: 0,
          rewards: 0,
        });
      }
    } else if (period === 'month') {
      // Last 12 months
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      for (let i = 11; i >= 0; i--) {
        const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
        results.push({
          name: months[date.getMonth()],
          users: 0,
          withdrawals: 0,
          rewards: 0,
        });
      }
    } else {
      // Last 4 years
      for (let i = 3; i >= 0; i--) {
        const year = now.getFullYear() - i;
        results.push({
          name: year.toString(),
          users: 0,
          withdrawals: 0,
          rewards: 0,
        });
      }
    }

    // Get actual counts from database
    try {
      const devicesSnapshot = await adminDb.collection('devices').get();
      const withdrawalsSnapshot = await adminDb.collection('withdrawals').get();
      const rewardsSnapshot = await adminDb.collection('activity_logs').where('type', '==', 'ad_reward').get();

      // Add totals to last item in results
      if (results.length > 0) {
        results[results.length - 1] = {
          ...results[results.length - 1],
          users: devicesSnapshot.size,
          withdrawals: withdrawalsSnapshot.docs.reduce((sum, doc) => sum + (doc.data().points || 0), 0),
          rewards: rewardsSnapshot.docs.reduce((sum, doc) => sum + (doc.data().amount || 0), 0),
        };
      }
    } catch (dbError) {
      console.error('Database query error:', dbError);
    }

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
