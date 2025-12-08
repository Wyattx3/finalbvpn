const admin = require('firebase-admin');
const serviceAccount = require('../../admin-dashboard/firebase-admin-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function parseTimestamp(timestamp) {
  if (!timestamp) return null;
  if (timestamp.toDate) return timestamp.toDate();
  if (timestamp instanceof Date) return timestamp;
  if (typeof timestamp === 'string') return new Date(timestamp);
  if (typeof timestamp === 'number') return new Date(timestamp);
  return null;
}

async function testApiOutput() {
  console.log('=== TESTING API OUTPUT ===');
  console.log('Server time:', new Date().toISOString());
  console.log('');

  const devicesSnapshot = await db.collection('devices').get();
  const withdrawalsSnapshot = await db.collection('withdrawals').get();

  for (const period of ['day', 'month', 'year']) {
    console.log(`\n=== ${period.toUpperCase()} VIEW ===`);
    
    const dataByDate = new Map();

    // Process devices
    devicesSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      const createdAt = parseTimestamp(data.createdAt);
      
      if (createdAt) {
        let key, displayKey;
        
        if (period === 'day') {
          displayKey = `${MONTHS[createdAt.getMonth()]} ${createdAt.getDate()}`;
          key = `${createdAt.getFullYear()}-${String(createdAt.getMonth()+1).padStart(2,'0')}-${String(createdAt.getDate()).padStart(2,'0')}`;
        } else if (period === 'month') {
          displayKey = MONTHS[createdAt.getMonth()];
          key = `${createdAt.getFullYear()}-${String(createdAt.getMonth()+1).padStart(2,'0')}`;
        } else {
          displayKey = createdAt.getFullYear().toString();
          key = displayKey;
        }
        
        if (!dataByDate.has(key)) {
          dataByDate.set(key, { users: 0, withdrawals: 0, rewards: 0, displayKey, sortKey: key });
        }
        const entry = dataByDate.get(key);
        entry.users += 1;
        entry.rewards += data.balance || 0;
      }
    });

    // Process withdrawals
    withdrawalsSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (data.status !== 'approved') return;
      
      const createdAt = parseTimestamp(data.createdAt);
      const points = data.points || 0;
      
      if (createdAt) {
        let key, displayKey;
        
        if (period === 'day') {
          displayKey = `${MONTHS[createdAt.getMonth()]} ${createdAt.getDate()}`;
          key = `${createdAt.getFullYear()}-${String(createdAt.getMonth()+1).padStart(2,'0')}-${String(createdAt.getDate()).padStart(2,'0')}`;
        } else if (period === 'month') {
          displayKey = MONTHS[createdAt.getMonth()];
          key = `${createdAt.getFullYear()}-${String(createdAt.getMonth()+1).padStart(2,'0')}`;
        } else {
          displayKey = createdAt.getFullYear().toString();
          key = displayKey;
        }
        
        if (!dataByDate.has(key)) {
          dataByDate.set(key, { users: 0, withdrawals: 0, rewards: 0, displayKey, sortKey: key });
        }
        const entry = dataByDate.get(key);
        entry.withdrawals += points;
      }
    });

    // Sort and output
    const results = Array.from(dataByDate.values())
      .sort((a, b) => a.sortKey.localeCompare(b.sortKey));

    results.forEach(entry => {
      console.log(`  ${entry.displayKey}: users=${entry.users}, withdrawals=${entry.withdrawals} MMK, rewards=${entry.rewards} MMK`);
    });
  }

  process.exit(0);
}

testApiOutput().catch(console.error);

