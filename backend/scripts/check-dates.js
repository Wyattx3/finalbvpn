const admin = require('firebase-admin');
const serviceAccount = require('../../admin-dashboard/firebase-admin-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkDates() {
  console.log('=== CHECKING ACTUAL DATES IN FIREBASE ===\n');
  console.log('Today is:', new Date().toISOString().split('T')[0]);
  
  // Check devices
  const devices = await db.collection('devices').get();
  console.log('\n=== DEVICES CREATED DATES ===');
  const deviceDates = {};
  devices.docs.forEach(doc => {
    const data = doc.data();
    const createdAt = data.createdAt?.toDate?.() || data.createdAt;
    if (createdAt) {
      const dateStr = new Date(createdAt).toISOString().split('T')[0];
      deviceDates[dateStr] = (deviceDates[dateStr] || 0) + 1;
    } else {
      console.log('  No createdAt:', doc.id.slice(0, 12));
    }
  });
  
  // Sort by date
  const sortedDeviceDates = Object.entries(deviceDates).sort((a, b) => a[0].localeCompare(b[0]));
  sortedDeviceDates.forEach(([date, count]) => {
    console.log(`  ${date}: ${count} devices`);
  });

  // Check withdrawals
  const withdrawals = await db.collection('withdrawals').get();
  console.log('\n=== WITHDRAWALS DATES ===');
  withdrawals.docs.forEach(doc => {
    const data = doc.data();
    const createdAt = data.createdAt?.toDate?.() || data.createdAt;
    const dateStr = createdAt ? new Date(createdAt).toISOString().split('T')[0] : 'NO DATE';
    console.log(`  ${doc.id.slice(0, 12)}: ${dateStr} - ${data.points} pts (${data.status})`);
  });

  // Check activity_logs
  const logs = await db.collection('activity_logs').get();
  console.log('\n=== ACTIVITY LOGS DATES ===');
  const logDates = {};
  logs.docs.forEach(doc => {
    const data = doc.data();
    const createdAt = data.createdAt?.toDate?.() || data.createdAt || data.timestamp?.toDate?.() || data.timestamp;
    if (createdAt) {
      const dateStr = new Date(createdAt).toISOString().split('T')[0];
      logDates[dateStr] = (logDates[dateStr] || 0) + 1;
    }
  });
  
  const sortedLogDates = Object.entries(logDates).sort((a, b) => a[0].localeCompare(b[0]));
  sortedLogDates.forEach(([date, count]) => {
    console.log(`  ${date}: ${count} logs`);
  });

  process.exit(0);
}

checkDates().catch(console.error);

