const admin = require('firebase-admin');
const serviceAccount = require('../../admin-dashboard/firebase-admin-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function cleanupTestWithdrawals() {
  console.log('🧹 Cleaning up test/seed withdrawals...\n');
  
  const withdrawals = await db.collection('withdrawals').get();
  
  let deletedCount = 0;
  let keptCount = 0;
  
  for (const doc of withdrawals.docs) {
    const data = doc.data();
    const points = data.points || 0;
    const status = data.status;
    
    // Delete test withdrawals:
    // 1. Rejected withdrawals (clearly test data)
    // 2. Very large amounts (500,000+) that are unrealistic
    // 3. Round numbers that look like test data (50,000, 20,000, 10,000)
    const isTestData = 
      status === 'rejected' || 
      points >= 500000 ||
      (points >= 10000 && points % 10000 === 0); // Round test amounts
    
    if (isTestData) {
      console.log(`  ❌ Deleting: ${doc.id} - ${points} points (${status})`);
      await db.collection('withdrawals').doc(doc.id).delete();
      deletedCount++;
    } else {
      console.log(`  ✅ Keeping: ${doc.id} - ${points} points (${status})`);
      keptCount++;
    }
  }
  
  console.log('\n' + '='.repeat(50));
  console.log(`✨ Cleanup complete!`);
  console.log(`   Deleted: ${deletedCount} test withdrawals`);
  console.log(`   Kept: ${keptCount} real withdrawals`);
  
  process.exit(0);
}

cleanupTestWithdrawals().catch(console.error);

