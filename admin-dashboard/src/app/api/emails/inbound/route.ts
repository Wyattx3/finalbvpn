import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';
import { Resend } from 'resend';

const resend = new Resend('re_3n6PdRpe_4MxmLmbwnh9VVcb4sRfXCReU');

// Resend Inbound Email Webhook
export async function POST(request: Request) {
  try {
    const body = await request.json();
    
    console.log('📧 Received webhook event:', body.type);
    
    // Only process email.received events (inbound emails)
    if (body.type !== 'email.received') {
      console.log('📧 Skipping non-inbound event:', body.type);
      return NextResponse.json({ 
        success: true, 
        message: `Skipped event type: ${body.type}` 
      });
    }
    
    const emailData = body.data;
    
    if (!emailData || !emailData.from) {
      console.error('❌ No email data in webhook');
      return NextResponse.json({ 
        success: false, 
        error: 'Invalid webhook data' 
      }, { status: 400 });
    }

    const { from, to, subject, email_id, attachments, created_at } = emailData;

    console.log('📧 Processing inbound email:', { from, subject, email_id });

    // Extract sender email
    let senderEmail = from;
    if (typeof from === 'string') {
      const emailMatch = from.match(/<(.+)>/);
      if (emailMatch) {
        senderEmail = emailMatch[1];
      }
    }

    // Fetch full email content using Resend SDK
    let emailContent = { text: '', html: '' };
    if (email_id) {
      try {
        console.log('📧 Fetching email content for:', email_id);
        const { data: fullEmail, error } = await resend.emails.get(email_id);
        
        if (error) {
          console.error('❌ Resend API error:', error);
        } else if (fullEmail) {
          emailContent = {
            text: (fullEmail as any).text || '',
            html: (fullEmail as any).html || '',
          };
          console.log('📧 Email content fetched successfully');
        }
      } catch (fetchError) {
        console.error('❌ Error fetching email content:', fetchError);
      }
    }

    // Save to Firestore
    const emailDoc = await adminDb.collection('email_inbox').add({
      from: senderEmail,
      fromFull: from,
      to: Array.isArray(to) ? to.join(', ') : to,
      subject: subject || '(No Subject)',
      body: emailContent.text,
      htmlBody: emailContent.html,
      emailId: email_id,
      receivedAt: created_at ? new Date(created_at) : new Date(),
      status: 'unread',
      isStarred: false,
      attachmentCount: attachments?.length || 0,
    });

    console.log('✅ Email saved to Firestore:', emailDoc.id);

    return NextResponse.json({ 
      success: true, 
      message: 'Email received and saved',
      emailId: emailDoc.id 
    });
  } catch (error: any) {
    console.error('❌ Error processing inbound email:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to process email', details: error.message },
      { status: 500 }
    );
  }
}

// GET endpoint for webhook verification
export async function GET() {
  return NextResponse.json({ 
    status: 'ok', 
    message: 'Inbound email webhook is ready',
    endpoint: '/api/emails/inbound',
    timestamp: new Date().toISOString()
  });
}

