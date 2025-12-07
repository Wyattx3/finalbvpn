import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// POST - Log admin login activity
export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { email, device, browser, os, ip, location, sessionId, isActive } = body;

    // Save to Firebase
    const docRef = await adminDb.collection('admin_login_activity').add({
      email: email || 'admin@bvpn.com',
      device: device || 'Unknown Device',
      browser: browser || 'Unknown Browser',
      os: os || 'Unknown OS',
      ip: ip || 'Unknown',
      location: location || 'Unknown',
      sessionId: sessionId || null,
      isActive: isActive ?? true,
      lastActivity: new Date(),
      timestamp: new Date(),
      type: 'login',
    });

    console.log('📝 Admin login activity logged:', docRef.id);

    return NextResponse.json({ success: true, docId: docRef.id });
  } catch (error) {
    console.error('Error logging admin login:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to log login activity' },
      { status: 500 }
    );
  }
}

// PUT - Update session activity (heartbeat)
export async function PUT(request: Request) {
  try {
    const body = await request.json();
    const { sessionId, action } = body;

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
    
    if (action === 'logout') {
      // Mark session as inactive on logout
      await doc.ref.update({
        isActive: false,
        lastActivity: new Date(),
      });
      console.log('🔴 Admin session ended:', sessionId);
    } else {
      // Update last activity (heartbeat)
      await doc.ref.update({
        lastActivity: new Date(),
        isActive: true,
      });
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error updating session:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to update session' },
      { status: 500 }
    );
  }
}

// GET - Fetch admin login activity
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const limitParam = searchParams.get('limit') || '100';
    const limitNum = parseInt(limitParam);

    const snapshot = await adminDb
      .collection('admin_login_activity')
      .orderBy('timestamp', 'desc')
      .limit(limitNum)
      .get();

    const activities = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        email: data.email,
        device: data.device,
        browser: data.browser,
        os: data.os,
        ip: data.ip,
        location: data.location,
        timestamp: data.timestamp?.toDate?.()?.toISOString() || new Date().toISOString(),
        type: data.type,
      };
    });

    return NextResponse.json({ success: true, activities });
  } catch (error) {
    console.error('Error fetching admin login activity:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch login activity', activities: [] },
      { status: 500 }
    );
  }
}

