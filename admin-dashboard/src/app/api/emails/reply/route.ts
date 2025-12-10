import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { to, subject, message, originalEmailId } = body;

    const resendApiKey = 're_3n6PdRpe_4MxmLmbwnh9VVcb4sRfXCReU';
    
    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Suk Fhyoke Support <support@sukfhyoke.com>',
        to: to,
        reply_to: 'support@sukfhyoke.com',
        subject: subject.startsWith('Re:') ? subject : `Re: ${subject}`,
        html: `
          <div style="font-family: Arial, sans-serif; padding: 20px;">
            <div style="text-align: center; margin-bottom: 20px;">
              <h1 style="color: #7c3aed; margin: 0;">Suk Fhyoke VPN</h1>
              <p style="color: #666;">Customer Support</p>
            </div>
            ${message.replace(/\n/g, '<br>')}
            <br><br>
            <hr style="border: none; border-top: 1px solid #ddd;">
            <p style="color: #666; font-size: 12px;">Sent from Suk Fhyoke VPN Support</p>
          </div>
        `,
      }),
    });

    if (!emailResponse.ok) {
      const errorData = await emailResponse.json();
      console.error('Resend API Error:', errorData);
      return NextResponse.json(
        { success: false, error: errorData.message || 'Failed to send email' },
        { status: 500 }
      );
    }

    const result = await emailResponse.json();
    console.log('✅ Email sent:', result.id);

    return NextResponse.json({ success: true, emailId: result.id });
  } catch (error) {
    console.error('Error sending reply:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to send reply' },
      { status: 500 }
    );
  }
}

