import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// DELETE - Clean up all devices (for testing purposes)
export async function DELETE() {
  try {
    const devicesRef = adminDb.collection('devices');
    const snapshot = await devicesRef.get();
    
    const batch = adminDb.batch();
    let count = 0;
    
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      count++;
    });
    
    if (count > 0) {
      await batch.commit();
    }
    
    return NextResponse.json({
      success: true,
      message: `Deleted ${count} device(s)`,
      deletedCount: count,
    });
  } catch (error) {
    console.error('Error cleaning up devices:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to cleanup devices' },
      { status: 500 }
    );
  }
}

// GET - Get cleanup status
export async function GET() {
  try {
    const devicesRef = adminDb.collection('devices');
    const snapshot = await devicesRef.get();
    
    return NextResponse.json({
      success: true,
      deviceCount: snapshot.size,
      devices: snapshot.docs.map(doc => ({
        id: doc.id,
        deviceModel: doc.data().deviceModel || 'Unknown',
        createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
      })),
    });
  } catch (error) {
    console.error('Error getting devices:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to get devices' },
      { status: 500 }
    );
  }
}

