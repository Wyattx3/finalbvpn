const admin = require('firebase-admin');

// Initialize with default credentials
admin.initializeApp({
  projectId: 'strategic-volt-341100'
});

const db = admin.firestore();

async function cleanupMockServers() {
  console.log('🧹 Starting cleanup of mock servers...');
  
  const serversRef = db.collection('servers');
  const snapshot = await serversRef.get();
  
  if (snapshot.empty) {
    console.log('No servers found.');
    return;
  }

  const batch = db.batch();
  let deleteCount = 0;

  snapshot.forEach(doc => {
    const data = doc.data();
    // Delete if address contains 'example.com' or it's not our real IP
    // Our real IP is 35.247.157.141
    if (data.address && (data.address.includes('example.com') || (data.address !== '35.247.157.141'))) {
      console.log(`🗑️ Deleting mock server: ${data.name} (${data.address})`);
      batch.delete(doc.ref);
      deleteCount++;
    } else {
      console.log(`✅ Keeping real server: ${data.name} (${data.address})`);
    }
  });

  if (deleteCount > 0) {
    await batch.commit();
    console.log(`✨ Successfully deleted ${deleteCount} mock servers.`);
  } else {
    console.log('✨ No mock servers found to delete.');
  }
}

cleanupMockServers().then(() => {
  console.log('Done.');
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});

