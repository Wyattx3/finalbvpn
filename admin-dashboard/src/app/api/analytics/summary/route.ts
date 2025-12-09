import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// Get analytics summary
export async function GET() {
  try {
    // Total Users (devices)
    const devicesSnapshot = await adminDb.collection('devices').get();
    const totalUsers = devicesSnapshot.size;

    // New users today - check createdAt timestamp
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    let newUsersToday = 0;
    let yesterdayUsers = 0;
    
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    
    devicesSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      const createdAt = data.createdAt?.toDate?.() || data.createdAt;
      
      if (createdAt) {
        const createdDate = new Date(createdAt);
        if (createdDate >= today) {
          newUsersToday++;
        } else if (createdDate >= yesterday && createdDate < today) {
          yesterdayUsers++;
        }
      }
    });
    
    // Calculate user change percentage
    const userChange = yesterdayUsers > 0 
      ? Math.round(((newUsersToday - yesterdayUsers) / yesterdayUsers) * 100)
      : (newUsersToday > 0 ? 100 : 0);

    // Active servers
    const serversSnapshot = await adminDb.collection('servers').where('status', '==', 'online').get();
    const activeServers = serversSnapshot.size;

    // Withdrawals this month - ONLY APPROVED withdrawals (real data)
    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
    const withdrawalsSnapshot = await adminDb.collection('withdrawals').get();
    let withdrawalsThisMonth = 0;
    let lastMonthWithdrawals = 0;
    
    const lastMonthStart = new Date(today.getFullYear(), today.getMonth() - 1, 1);
    const lastMonthEnd = new Date(today.getFullYear(), today.getMonth(), 0);
    
    withdrawalsSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      // Only count APPROVED withdrawals
      if (data.status !== 'approved') return;
      
      const createdAt = data.createdAt?.toDate?.() || data.createdAt;
      const amount = data.points || 0;
      
      if (createdAt) {
        const date = new Date(createdAt);
        if (date >= startOfMonth) {
          withdrawalsThisMonth += amount;
        } else if (date >= lastMonthStart && date <= lastMonthEnd) {
          lastMonthWithdrawals += amount;
        }
      } else {
        withdrawalsThisMonth += amount;
      }
    });
    
    // Calculate withdrawal change percentage
    const withdrawalChange = lastMonthWithdrawals > 0
      ? Math.round(((withdrawalsThisMonth - lastMonthWithdrawals) / lastMonthWithdrawals) * 100)
      : (withdrawalsThisMonth > 0 ? 100 : 0);

    // Rewards earned THIS MONTH only - Calculate REAL data only
    // Only count approved withdrawals this month (actual cash out this month)
    let rewardsThisMonth = 0;
    let todayRewards = 0;
    
    // Sum today's earnings from all devices
    devicesSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      todayRewards += data.todayEarnings || 0;
    });
    
    // Only count APPROVED withdrawals this month as "rewards earned"
    // This represents actual value given to users this month
    withdrawalsSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (data.status !== 'approved') return;
      
      const createdAt = data.createdAt?.toDate?.() || data.createdAt;
      const amount = data.points || 0;
      
      if (createdAt) {
        const date = new Date(createdAt);
        if (date >= startOfMonth) {
          rewardsThisMonth += amount;
        }
      }
    });
    
    // Add today's earnings to this month's rewards
    rewardsThisMonth += todayRewards;

    // Pending withdrawals
    const pendingSnapshot = await adminDb.collection('withdrawals').where('status', '==', 'pending').get();
    const pendingWithdrawals = pendingSnapshot.size;

    return NextResponse.json({
      success: true,
      stats: {
        totalUsers,
        newUsersToday,
        userChange,
        activeServers,
        withdrawalsThisMonth,
        withdrawalChange,
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
