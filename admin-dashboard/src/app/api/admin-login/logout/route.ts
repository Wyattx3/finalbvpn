import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// POST - Mark session as inactive (used by sendBeacon on browser close)
export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { sessionId } = body;

    if (!sessionId) {
      return NextResponse.json({ success: false, error: 'Session ID required' }, { status: 400 });
    }

    // Find session by sessionId
    const snapshot = await adminDb
      .collection('admin_login_activity')
      .where('sessionId', '==', sessionId)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return NextResponse.json({ success: false, error: 'Session not found' }, { status: 404 });
    }

    const doc = snapshot.docs[0];
    
    // Mark session as inactive
    await doc.ref.update({
      isActive: false,
      lastActivity: new Date(),
    });
    
    console.log('🔴 Admin session ended (browser closed):', sessionId);

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error ending session:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to end session' },
      { status: 500 }
    );
  }
}


