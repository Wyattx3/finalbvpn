import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// Debug endpoint to check raw email payloads
export async function GET() {
  try {
    const snapshot = await adminDb.collection('email_inbox')
      .orderBy('receivedAt', 'desc')
      .limit(5)
      .get();
    
    const emails = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        from: data.from,
        subject: data.subject,
        body: data.body,
        htmlBody: data.htmlBody,
        rawPayload: data.rawPayload,
      };
    });

    return NextResponse.json({ 
      success: true, 
      emails,
      message: 'Check rawPayload to see actual Resend format'
    });
  } catch (error: any) {
    return NextResponse.json({ 
      success: false, 
      error: error.message 
    }, { status: 500 });
  }
}


