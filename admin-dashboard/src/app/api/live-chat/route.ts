import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// GET - Fetch all live chat threads
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status') || undefined;
    const limit = parseInt(searchParams.get('limit') || '100');

    let query = adminDb.collection('live_chats').orderBy('lastMessageAt', 'desc');
    
    if (status) {
      query = query.where('status', '==', status) as any;
    }

    const snapshot = await query.limit(limit).get();

    const chats = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        deviceId: data.deviceId,
        deviceModel: data.deviceModel,
        status: data.status || 'active',
        messages: data.messages || [],
        createdAt: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
        lastMessageAt: data.lastMessageAt?.toDate?.()?.toISOString() || new Date().toISOString(),
      };
    });

    return NextResponse.json({ success: true, chats });
  } catch (error) {
    console.error('Error fetching live chats:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch chats' },
      { status: 500 }
    );
  }
}

// POST - Send admin reply to live chat
export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { deviceId, message } = body;

    if (!deviceId || !message) {
      return NextResponse.json(
        { success: false, error: 'Device ID and message required' },
        { status: 400 }
      );
    }

    // Get or create chat thread
    const chatRef = adminDb.collection('live_chats').doc(deviceId);
    const chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      return NextResponse.json(
        { success: false, error: 'Chat thread not found' },
        { status: 404 }
      );
    }

    const chatData = chatDoc.data()!;

    // Add admin message
    const adminMessage = {
      id: Date.now().toString(),
      sender: 'admin',
      senderId: 'admin',
      message: message,
      timestamp: new Date(),
      read: false,
    };

    await chatRef.update({
      messages: [...(chatData.messages || []), adminMessage],
      lastMessageAt: new Date(),
      status: 'active',
    });

    return NextResponse.json({ success: true, message: 'Message sent' });
  } catch (error) {
    console.error('Error sending chat reply:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to send reply' },
      { status: 500 }
    );
  }
}

