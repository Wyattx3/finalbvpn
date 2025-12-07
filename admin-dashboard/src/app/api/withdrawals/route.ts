import { NextResponse } from 'next/server';
import { getAllWithdrawals, processWithdrawal } from '@/lib/firebase-admin';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '100');
    const status = searchParams.get('status') || undefined;

    const withdrawals = await getAllWithdrawals(limit, status);
    return NextResponse.json({ success: true, withdrawals });
  } catch (error) {
    console.error('Error fetching withdrawals:', error);
    return NextResponse.json({ success: false, error: 'Failed to fetch withdrawals' }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { withdrawalId, action, rejectionReason, transactionId, receiptImage } = body;

    if (!withdrawalId || !action) {
      return NextResponse.json({ success: false, error: 'Missing required fields' }, { status: 400 });
    }

    if (action !== 'approved' && action !== 'rejected') {
      return NextResponse.json({ success: false, error: 'Invalid action' }, { status: 400 });
    }

    // Validate required fields for each action
    if (action === 'approved') {
      if (!receiptImage) {
        return NextResponse.json({ 
          success: false, 
          error: 'Receipt Image is required for approval' 
        }, { status: 400 });
      }
    }

    if (action === 'rejected') {
      if (!rejectionReason || !rejectionReason.trim()) {
        return NextResponse.json({ 
          success: false, 
          error: 'Rejection reason is required' 
        }, { status: 400 });
      }
    }

    await processWithdrawal(withdrawalId, action, {
      rejectionReason,
      transactionId,
      receiptImage,
    });
    
    return NextResponse.json({ success: true, message: `Withdrawal ${action}` });
  } catch (error) {
    console.error('Error processing withdrawal:', error);
    return NextResponse.json({ success: false, error: 'Failed to process withdrawal' }, { status: 500 });
  }
}
