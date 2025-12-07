import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// Get analytics summary
export async function GET() {
  try {
    // Total Users (devices)
    const devicesSnapshot = await adminDb.collection('devices').get();
    const totalUsers = devicesSnapshot.size;

    // Active servers
    const serversSnapshot = await adminDb.collection('servers').where('status', '==', 'online').get();
    const activeServers = serversSnapshot.size;

    // Withdrawals
    const withdrawalsSnapshot = await adminDb.collection('withdrawals').get();
    let withdrawalsThisMonth = 0;
    withdrawalsSnapshot.docs.forEach((doc) => {
      withdrawalsThisMonth += doc.data().points || 0;
    });

    // Rewards earned
    const rewardsSnapshot = await adminDb.collection('activity_logs').where('type', '==', 'ad_reward').get();
    let rewardsThisMonth = 0;
    rewardsSnapshot.docs.forEach((doc) => {
      rewardsThisMonth += doc.data().amount || 0;
    });

    // Pending withdrawals
    const pendingSnapshot = await adminDb.collection('withdrawals').where('status', '==', 'pending').get();
    const pendingWithdrawals = pendingSnapshot.size;

    return NextResponse.json({
      success: true,
      stats: {
        totalUsers,
        newUsersToday: 0,
        userChange: 0,
        activeServers,
        withdrawalsThisMonth,
        withdrawalChange: 0,
        rewardsThisMonth,
        pendingWithdrawals,
      },
    });
  } catch (error) {
    console.error('Error fetching analytics summary:', error);
    return NextResponse.json({
      success: true,
      stats: {
        totalUsers: 0,
        newUsersToday: 0,
        userChange: 0,
        activeServers: 0,
        withdrawalsThisMonth: 0,
        withdrawalChange: 0,
        rewardsThisMonth: 0,
        pendingWithdrawals: 0,
      },
    });
  }
}
