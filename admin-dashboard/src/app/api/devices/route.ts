import { NextResponse } from 'next/server';
import { getAllDevices, toggleDeviceBan, adjustBalance, adjustVpnTime, getActivityLogs } from '@/lib/firebase-admin';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '100');
    const status = searchParams.get('status') || undefined;

    const devices = await getAllDevices(limit, status);
    return NextResponse.json({ success: true, devices });
  } catch (error) {
    console.error('Error fetching devices:', error);
    return NextResponse.json({ success: false, error: 'Failed to fetch devices' }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { action, deviceId, ...params } = body;

    switch (action) {
      case 'ban':
        await toggleDeviceBan(deviceId, true, params.reason);
        return NextResponse.json({ success: true, message: 'Device banned' });

      case 'unban':
        await toggleDeviceBan(deviceId, false);
        return NextResponse.json({ success: true, message: 'Device unbanned' });

      case 'adjustBalance':
        const result = await adjustBalance(deviceId, params.amount, params.reason);
        return NextResponse.json(result);

      case 'adjustVpnTime':
        const vpnResult = await adjustVpnTime(deviceId, params.seconds, params.reason);
        return NextResponse.json(vpnResult);

      case 'getLogs':
        const logs = await getActivityLogs(deviceId, params.limit || 50);
        return NextResponse.json({ success: true, logs });

      default:
        return NextResponse.json({ success: false, error: 'Invalid action' }, { status: 400 });
    }
  } catch (error) {
    console.error('Error processing device action:', error);
    return NextResponse.json({ success: false, error: 'Failed to process action' }, { status: 500 });
  }
}

