const admin = require('firebase-admin');
const serviceAccount = require('../../admin-dashboard/firebase-admin-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkData() {
  // Check devices
  const devices = await db.collection('devices').get();
  let totalBalance = 0;
  console.log('=== DEVICES ===');
  console.log('Total devices:', devices.size);
  devices.docs.forEach(doc => {
    const d = doc.data();
    totalBalance += d.balance || 0;
    if (d.balance > 0) {
      console.log('  Device:', doc.id.slice(0, 12), 'Balance:', d.balance);
    }
  });
  console.log('📊 Total balance sum:', totalBalance);

  // Check withdrawals
  const withdrawals = await db.collection('withdrawals').get();
  let totalWithdrawals = 0;
  console.log('\n=== WITHDRAWALS ===');
  console.log('Total withdrawals:', withdrawals.size);
  withdrawals.docs.forEach(doc => {
    const d = doc.data();
    totalWithdrawals += d.points || 0;
    console.log('  Withdrawal:', doc.id.slice(0, 12), 'Points:', d.points, 'Status:', d.status);
  });
  console.log('📊 Total withdrawals sum:', totalWithdrawals);

  // Check activity_logs
  const activityLogs = await db.collection('activity_logs').get();
  let totalRewards = 0;
  console.log('\n=== ACTIVITY LOGS ===');
  console.log('Total logs:', activityLogs.size);
  activityLogs.docs.forEach(doc => {
    const d = doc.data();
    if (d.type === 'ad_reward') {
      totalRewards += d.amount || 0;
    }
  });
  console.log('📊 Total ad rewards from logs:', totalRewards);

  console.log('\n=== SUMMARY ===');
  console.log('Balance sum:', totalBalance);
  console.log('Withdrawals sum:', totalWithdrawals);
  console.log('Activity logs rewards:', totalRewards);
  console.log('Balance + Withdrawals =', totalBalance + totalWithdrawals);
  
  process.exit(0);
}

checkData().catch(console.error);

