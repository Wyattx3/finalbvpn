/**
 * BVPN - Reset Bandwidth Data Script
 * Resets all bandwidth/usage data to 0 after fixing the delta sync bug
 * 
 * Usage: node scripts/reset-bandwidth.js
 */

const admin = require('firebase-admin');

admin.initializeApp({
  projectId: 'strategic-volt-341100'
});

const db = admin.firestore();

async function resetAllBandwidthData() {
  console.log('🔄 Resetting all bandwidth data to real values (0)...\n');

  try {
    // 1. Reset all servers bandwidth
    console.log('📡 Resetting server bandwidth...');
    const serversSnapshot = await db.collection('servers').get();
    const serverBatch = db.batch();
    
    serversSnapshot.forEach(doc => {
      console.log(`   - Resetting server: ${doc.data().name || doc.id}`);
      serverBatch.update(doc.ref, {
        bandwidthUsed: 0,
        totalConnections: 0,
        lastActivity: null
      });
    });
    
    await serverBatch.commit();
    console.log(`✅ Reset ${serversSnapshot.size} servers\n`);

    // 2. Reset all devices dataUsage
    console.log('📱 Resetting device data usage...');
    const devicesSnapshot = await db.collection('devices').get();
    const deviceBatch = db.batch();
    
    devicesSnapshot.forEach(doc => {
      console.log(`   - Resetting device: ${doc.id}`);
      deviceBatch.update(doc.ref, {
        dataUsage: 0,
        lastVpnActivity: null
      });
    });
    
    await deviceBatch.commit();
    console.log(`✅ Reset ${devicesSnapshot.size} devices\n`);

    // 3. Delete all vpn_sessions (corrupted data)
    console.log('🗑️ Deleting corrupted VPN sessions...');
    const sessionsSnapshot = await db.collection('vpn_sessions').get();
    
    if (sessionsSnapshot.size > 0) {
      // Delete in batches of 500 (Firestore limit)
      const batches = [];
      let currentBatch = db.batch();
      let operationCount = 0;
      
      sessionsSnapshot.forEach(doc => {
        currentBatch.delete(doc.ref);
        operationCount++;
        
        if (operationCount === 500) {
          batches.push(currentBatch);
          currentBatch = db.batch();
          operationCount = 0;
        }
      });
      
      if (operationCount > 0) {
        batches.push(currentBatch);
      }
      
      for (const batch of batches) {
        await batch.commit();
      }
      console.log(`✅ Deleted ${sessionsSnapshot.size} VPN sessions\n`);
    } else {
      console.log('   No VPN sessions to delete\n');
    }

    console.log('═══════════════════════════════════════════');
    console.log('✨ All bandwidth data has been reset to 0!');
    console.log('═══════════════════════════════════════════');
    console.log('\n📋 Summary:');
    console.log(`   - Servers reset: ${serversSnapshot.size}`);
    console.log(`   - Devices reset: ${devicesSnapshot.size}`);
    console.log(`   - Sessions deleted: ${sessionsSnapshot.size}`);
    console.log('\n💡 Now the app will track REAL bandwidth using delta sync.');

  } catch (error) {
    console.error('❌ Error resetting data:', error);
    process.exit(1);
  }

  process.exit(0);
}

resetAllBandwidthData();

