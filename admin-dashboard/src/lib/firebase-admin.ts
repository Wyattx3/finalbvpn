import { initializeApp, getApps, cert, App, ServiceAccount } from 'firebase-admin/app';
import { getFirestore, Firestore } from 'firebase-admin/firestore';
import { getAuth, Auth } from 'firebase-admin/auth';
import * as path from 'path';
import * as fs from 'fs';

// Firebase Admin initialization
let app: App;
let db: Firestore;
let auth: Auth;

function initializeFirebaseAdmin() {
  if (getApps().length === 0) {
    // Try to load service account key file
    const keyPath = path.join(process.cwd(), 'firebase-admin-key.json');
    
    if (fs.existsSync(keyPath)) {
      // Use service account key file
      const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8')) as ServiceAccount;
      app = initializeApp({
        credential: cert(serviceAccount),
        projectId: 'strategic-volt-341100',
      });
      console.log('✅ Firebase Admin initialized with service account key');
    } else {
      // Fallback to Application Default Credentials
      app = initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'strategic-volt-341100',
      });
      console.log('⚠️ Firebase Admin initialized with ADC (no key file found)');
    }
  } else {
    app = getApps()[0];
  }

  db = getFirestore(app);
  auth = getAuth(app);

  return { app, db, auth };
}

// Initialize on module load
const firebase = initializeFirebaseAdmin();

export const adminDb = firebase.db;
export const adminAuth = firebase.auth;
export const adminApp = firebase.app;

// ========== HELPER FUNCTIONS ==========

// Get all devices
export async function getAllDevices(limit = 100, status?: string) {
  let query = adminDb.collection('devices').orderBy('lastSeen', 'desc').limit(limit);
  
  if (status) {
    query = adminDb.collection('devices')
      .where('status', '==', status)
      .orderBy('lastSeen', 'desc')
      .limit(limit);
  }

  const snapshot = await query.get();
  return snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
    lastSeen: doc.data().lastSeen?.toDate?.()?.toISOString() || null,
  }));
}

// Get all withdrawals
export async function getAllWithdrawals(limit = 100, status?: string) {
  let query = adminDb.collection('withdrawals').orderBy('createdAt', 'desc').limit(limit);
  
  if (status) {
    query = adminDb.collection('withdrawals')
      .where('status', '==', status)
      .orderBy('createdAt', 'desc')
      .limit(limit);
  }

  const snapshot = await query.get();
  return snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
    processedAt: doc.data().processedAt?.toDate?.()?.toISOString() || null,
  }));
}

// Get all servers
export async function getAllServers() {
  const snapshot = await adminDb.collection('servers').get();
  return snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
  }));
}

// Get dashboard stats
export async function getDashboardStats() {
  const [devicesCount, serversCount, pendingWithdrawalsCount] = await Promise.all([
    adminDb.collection('devices').count().get(),
    adminDb.collection('servers').where('status', '==', 'online').count().get(),
    adminDb.collection('withdrawals').where('status', '==', 'pending').count().get(),
  ]);

  // Get total pending amount
  const pendingWithdrawals = await adminDb.collection('withdrawals')
    .where('status', '==', 'pending')
    .get();

  let totalPendingAmount = 0;
  pendingWithdrawals.docs.forEach(doc => {
    totalPendingAmount += doc.data().points || 0;
  });

  return {
    totalDevices: devicesCount.data().count,
    activeServers: serversCount.data().count,
    pendingWithdrawals: pendingWithdrawalsCount.data().count,
    totalPendingAmount,
  };
}

// Process withdrawal
interface ProcessWithdrawalOptions {
  rejectionReason?: string;
  transactionId?: string;
  receiptImage?: string; // base64 image
}

export async function processWithdrawal(
  withdrawalId: string, 
  action: 'approved' | 'rejected', 
  options?: ProcessWithdrawalOptions
) {
  const withdrawalRef = adminDb.collection('withdrawals').doc(withdrawalId);
  const withdrawalDoc = await withdrawalRef.get();

  if (!withdrawalDoc.exists) {
    throw new Error('Withdrawal not found');
  }

  const withdrawalData = withdrawalDoc.data()!;

  if (withdrawalData.status !== 'pending') {
    throw new Error('Withdrawal already processed');
  }

  const batch = adminDb.batch();

  // Build update data
  const updateData: Record<string, any> = {
    status: action,
    processedAt: new Date(),
  };

  // If approved, add transaction ID and receipt
  if (action === 'approved' && options) {
    if (options.transactionId) {
      updateData.transactionId = options.transactionId;
    }
    if (options.receiptImage) {
      // Store the base64 image directly in Firestore (for simplicity)
      // In production, you'd want to upload to Firebase Storage
      updateData.receiptUrl = options.receiptImage;
    }

    // Log completion
    const logRef = adminDb.collection('activity_logs').doc();
    batch.set(logRef, {
      deviceId: withdrawalData.deviceId,
      type: 'withdrawal',
      description: `Withdrawal Completed - ${options.transactionId}`,
      amount: -withdrawalData.points,
      timestamp: new Date(),
    });
  }

  // If rejected, add reason and refund balance
  if (action === 'rejected') {
    if (options?.rejectionReason) {
      updateData.rejectionReason = options.rejectionReason;
    }

    const deviceRef = adminDb.collection('devices').doc(withdrawalData.deviceId);
    const deviceDoc = await deviceRef.get();
    
    if (deviceDoc.exists) {
      const currentBalance = deviceDoc.data()?.balance || 0;
      batch.update(deviceRef, {
        balance: currentBalance + withdrawalData.points,
      });

      // Log refund
      const logRef = adminDb.collection('activity_logs').doc();
      batch.set(logRef, {
        deviceId: withdrawalData.deviceId,
        type: 'admin_adjustment',
        description: `Withdrawal Rejected - ${options?.rejectionReason || 'No reason'}`,
        amount: withdrawalData.points,
        timestamp: new Date(),
      });
    }
  }

  // Update withdrawal document
  batch.update(withdrawalRef, updateData);

  await batch.commit();
  return { success: true };
}

// Toggle device ban
export async function toggleDeviceBan(deviceId: string, ban: boolean, reason?: string) {
  const deviceRef = adminDb.collection('devices').doc(deviceId);
  const deviceDoc = await deviceRef.get();

  if (!deviceDoc.exists) {
    throw new Error('Device not found');
  }

  await deviceRef.update({
    status: ban ? 'banned' : 'offline',
    ...(ban && { banReason: reason || 'Banned by admin', bannedAt: new Date() }),
    ...(!ban && { banReason: null, bannedAt: null }),
  });

  return { success: true };
}

// Adjust balance
export async function adjustBalance(deviceId: string, amount: number, reason: string) {
  const deviceRef = adminDb.collection('devices').doc(deviceId);
  const deviceDoc = await deviceRef.get();

  if (!deviceDoc.exists) {
    throw new Error('Device not found');
  }

  const currentBalance = deviceDoc.data()?.balance || 0;
  const newBalance = currentBalance + amount;

  if (newBalance < 0) {
    throw new Error('Balance cannot go negative');
  }

  const batch = adminDb.batch();

  batch.update(deviceRef, { balance: newBalance });

  // Log activity
  const logRef = adminDb.collection('activity_logs').doc();
  batch.set(logRef, {
    deviceId,
    type: 'admin_adjustment',
    description: reason,
    amount,
    timestamp: new Date(),
  });

  await batch.commit();
  return { success: true, newBalance };
}

// Adjust VPN time for a device
export async function adjustVpnTime(deviceId: string, seconds: number, reason: string) {
  const deviceRef = adminDb.collection('devices').doc(deviceId);
  const deviceDoc = await deviceRef.get();

  if (!deviceDoc.exists) {
    throw new Error('Device not found');
  }

  const batch = adminDb.batch();

  batch.update(deviceRef, { vpnRemainingSeconds: Math.max(0, seconds) });

  // Log activity
  const logRef = adminDb.collection('activity_logs').doc();
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  batch.set(logRef, {
    deviceId,
    type: 'admin_adjustment',
    description: `VPN Time adjusted: ${hours}h ${minutes}m - ${reason}`,
    amount: 0, // No points change
    timestamp: new Date(),
  });

  await batch.commit();
  return { success: true, newVpnSeconds: seconds };
}

// Add server
export async function addServer(serverData: Record<string, unknown>) {
  const serverRef = adminDb.collection('servers').doc();
  await serverRef.set({
    ...serverData,
    createdAt: new Date(),
  });
  return { success: true, serverId: serverRef.id };
}

// Update server
export async function updateServer(serverId: string, updates: Record<string, unknown>) {
  const serverRef = adminDb.collection('servers').doc(serverId);
  await serverRef.update({
    ...updates,
    updatedAt: new Date(),
  });
  return { success: true };
}

// Delete server
export async function deleteServer(serverId: string) {
  await adminDb.collection('servers').doc(serverId).delete();
  return { success: true };
}

// Get SDUI configs
export async function getSduiConfigs() {
  const snapshot = await adminDb.collection('sdui_configs').get();
  const configs: Record<string, unknown> = {};
  snapshot.docs.forEach(doc => {
    configs[doc.id] = doc.data();
  });
  return configs;
}

// Update SDUI config
export async function updateSduiConfig(screenId: string, config: Record<string, unknown>) {
  await adminDb.collection('sdui_configs').doc(screenId).set({
    screen_id: screenId,
    config,
    updatedAt: new Date(),
  }, { merge: true });
  return { success: true };
}

// Get activity logs for device
export async function getActivityLogs(deviceId: string, limit = 50) {
  const snapshot = await adminDb.collection('activity_logs')
    .where('deviceId', '==', deviceId)
    .orderBy('timestamp', 'desc')
    .limit(limit)
    .get();

  return snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    timestamp: doc.data().timestamp?.toDate?.()?.toISOString() || null,
  }));
}

