import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// Get country distribution
export async function GET() {
  try {
    const snapshot = await adminDb.collection('devices').get();

    const countryMap: Record<string, number> = {};

    snapshot.docs.forEach((doc) => {
      const country = doc.data().country || 'Unknown';
      countryMap[country] = (countryMap[country] || 0) + 1;
    });

    // Sort by count and get top 5
    const sorted = Object.entries(countryMap)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5);

    const data = sorted.map(([name, value]) => ({ name, value }));

    // Add "Others" if there are more countries
    const topCount = data.reduce((sum, item) => sum + item.value, 0);
    const totalCount = snapshot.size;
    if (totalCount > topCount) {
      data.push({ name: 'Others', value: totalCount - topCount });
    }

    return NextResponse.json({
      success: true,
      data,
      total: totalCount,
    });
  } catch (error) {
    console.error('Error fetching country distribution:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch country distribution' },
      { status: 500 }
    );
  }
}

