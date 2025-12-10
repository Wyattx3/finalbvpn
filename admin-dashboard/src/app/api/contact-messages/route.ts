import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// GET - Fetch all contact messages
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status') || undefined;
    const limit = parseInt(searchParams.get('limit') || '100');

    let query = adminDb.collection('contact_messages').orderBy('createdAt', 'desc');
    
    if (status) {
      query = query.where('status', '==', status) as any;
    }

    const snapshot = await query.limit(limit).get();

    const messages = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        deviceId: data.deviceId,
        deviceModel: data.deviceModel,
        category: data.category,
        subject: data.subject,
        message: data.message,
        status: data.status || 'pending',
        createdAt: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
        replies: data.replies || [],
      };
    });

    return NextResponse.json({ success: true, messages });
  } catch (error) {
    console.error('Error fetching contact messages:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch messages' },
      { status: 500 }
    );
  }
}

// POST - Send email reply via Resend API
export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { messageId, replyMessage, recipientEmail } = body;

    if (!messageId || !replyMessage) {
      return NextResponse.json(
        { success: false, error: 'Message ID and reply message required' },
        { status: 400 }
      );
    }

    // Get the original message
    const messageDoc = await adminDb.collection('contact_messages').doc(messageId).get();
    if (!messageDoc.exists) {
      return NextResponse.json(
        { success: false, error: 'Message not found' },
        { status: 404 }
      );
    }

    const messageData = messageDoc.data()!;
    const deviceId = messageData.deviceId;

    // Send email via Resend API
    // Note: For production, you should verify sukfhyoke.com domain with Resend
    // Go to: https://resend.com/domains and add sukfhyoke.com, then add DNS records
    const resendApiKey = 're_3n6PdRpe_4MxmLmbwnh9VVcb4sRfXCReU';
    
    // Get recipient email from message data or use provided one
    const toEmail = recipientEmail || messageData.email;
    
    if (!toEmail) {
      // No email to send to - just save reply to Firestore
      console.warn('No recipient email found, saving reply to Firestore only');
      
      const reply = {
        message: replyMessage,
        sentAt: new Date(),
        sentBy: 'admin',
        emailSent: false,
      };

      await adminDb.collection('contact_messages').doc(messageId).update({
        status: 'replied',
        replies: [...(messageData.replies || []), reply],
      });

      return NextResponse.json({ 
        success: true, 
        message: 'Reply saved (no email - user did not provide email)',
        emailSent: false 
      });
    }
    
    let emailSent = false;
    try {
      // Use onboarding@resend.dev for testing if domain not verified
      // For production: change to 'Suk Fhyoke Support <support@sukfhyoke.com>'
      // after verifying domain at https://resend.com/domains
      const emailResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${resendApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: 'Suk Fhyoke Support <support@sukfhyoke.com>',
          to: toEmail,
          reply_to: 'support@sukfhyoke.com',
          subject: `Re: ${messageData.subject}`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
              <div style="text-align: center; margin-bottom: 20px;">
                <h1 style="color: #7c3aed; margin: 0;">Suk Fhyoke VPN</h1>
                <p style="color: #666;">Customer Support</p>
              </div>
              <h2 style="color: #333;">Reply to your inquiry</h2>
              <div style="background: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Original Subject:</strong> ${messageData.subject}</p>
                <p><strong>Category:</strong> ${messageData.category}</p>
                <p><strong>Your Message:</strong></p>
                <p style="background: #fff; padding: 15px; border-radius: 5px; margin-top: 10px;">${messageData.message.replace(/\n/g, '<br>')}</p>
              </div>
              <hr style="margin: 20px 0; border: none; border-top: 1px solid #ddd;">
              <div style="background: #e3f2fd; padding: 15px; border-radius: 5px;">
                <p><strong>Our Reply:</strong></p>
                <p style="margin-top: 10px;">${replyMessage.replace(/\n/g, '<br>')}</p>
              </div>
              <hr style="margin: 20px 0; border: none; border-top: 1px solid #ddd;">
              <p style="color: #666; font-size: 12px;">If you have any further questions, please reply to this email or contact us at support@sukfhyoke.com</p>
              <p style="color: #999; font-size: 11px;">Reference ID: ${deviceId}</p>
            </div>
          `,
        }),
      });

      if (!emailResponse.ok) {
        const errorData = await emailResponse.json();
        console.error('Resend API error:', errorData);
        // Check for specific errors
        if (errorData.message?.includes('domain')) {
          console.error('Domain not verified. Please verify sukfhyoke.com at https://resend.com/domains');
        }
      } else {
        emailSent = true;
        console.log('Email sent successfully to:', toEmail);
      }
    } catch (emailError) {
      console.error('Error sending email via Resend:', emailError);
    }

    // Save reply to Firestore
    const reply = {
      message: replyMessage,
      sentAt: new Date(),
      sentBy: 'admin',
      emailSent: emailSent,
      sentTo: toEmail,
    };

    await adminDb.collection('contact_messages').doc(messageId).update({
      status: 'replied',
      replies: [...(messageData.replies || []), reply],
    });

    return NextResponse.json({ 
      success: true, 
      message: emailSent ? 'Reply sent successfully via email' : 'Reply saved (email failed)',
      emailSent: emailSent
    });
  } catch (error) {
    console.error('Error sending reply:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to send reply' },
      { status: 500 }
    );
  }
}

// PUT - Update message status
export async function PUT(request: Request) {
  try {
    const body = await request.json();
    const { messageId, status } = body;

    if (!messageId || !status) {
      return NextResponse.json(
        { success: false, error: 'Message ID and status required' },
        { status: 400 }
      );
    }

    await adminDb.collection('contact_messages').doc(messageId).update({
      status: status,
    });

    return NextResponse.json({ success: true, message: 'Status updated' });
  } catch (error) {
    console.error('Error updating status:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to update status' },
      { status: 500 }
    );
  }
}

