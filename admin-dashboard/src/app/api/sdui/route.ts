import { NextResponse } from 'next/server';
import { getSduiConfigs, updateSduiConfig } from '@/lib/firebase-admin';

export async function GET() {
  try {
    const configs = await getSduiConfigs();
    return NextResponse.json({ success: true, configs });
  } catch (error) {
    console.error('Error fetching SDUI configs:', error);
    return NextResponse.json({ success: false, error: 'Failed to fetch configs' }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { screenId, config } = body;

    if (!screenId || !config) {
      return NextResponse.json({ success: false, error: 'Missing required fields' }, { status: 400 });
    }

    await updateSduiConfig(screenId, config);
    return NextResponse.json({ success: true, message: 'Config updated' });
  } catch (error) {
    console.error('Error updating SDUI config:', error);
    return NextResponse.json({ success: false, error: 'Failed to update config' }, { status: 500 });
  }
}

