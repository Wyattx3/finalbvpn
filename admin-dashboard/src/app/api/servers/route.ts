import { NextResponse } from 'next/server';
import { getAllServers, addServer, updateServer, deleteServer } from '@/lib/firebase-admin';

export async function GET() {
  try {
    const servers = await getAllServers();
    return NextResponse.json({ success: true, servers });
  } catch (error) {
    console.error('Error fetching servers:', error);
    return NextResponse.json({ success: false, error: 'Failed to fetch servers' }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { action, serverId, ...serverData } = body;

    switch (action) {
      case 'add':
        const addResult = await addServer(serverData);
        return NextResponse.json(addResult);

      case 'update':
        if (!serverId) {
          return NextResponse.json({ success: false, error: 'Server ID required' }, { status: 400 });
        }
        await updateServer(serverId, serverData);
        return NextResponse.json({ success: true, message: 'Server updated' });

      case 'delete':
        if (!serverId) {
          return NextResponse.json({ success: false, error: 'Server ID required' }, { status: 400 });
        }
        await deleteServer(serverId);
        return NextResponse.json({ success: true, message: 'Server deleted' });

      default:
        return NextResponse.json({ success: false, error: 'Invalid action' }, { status: 400 });
    }
  } catch (error) {
    console.error('Error processing server action:', error);
    return NextResponse.json({ success: false, error: 'Failed to process action' }, { status: 500 });
  }
}

