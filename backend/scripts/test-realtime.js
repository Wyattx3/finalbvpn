// Test script to listen to Firestore updates for the server
const admin = require('firebase-admin');

// Initialize with default credentials
admin.initializeApp({
  projectId: 'strategic-volt-341100'
});

const db = admin.firestore();
const SERVER_UUID = 'b0072dd6-5d4d-45f7-a462-dc9bc53d23a9';

console.log(`🎧 Listening for updates on server with UUID: ${SERVER_UUID}`);

async function listenToServer() {
  const snapshot = await db.collection('servers').where('uuid', '==', SERVER_UUID).get();
  
  if (snapshot.empty) {
    console.log('❌ Server not found via UUID lookup');
    return;
  }

  const serverDoc = snapshot.docs[0];
  console.log(`✅ Found server: ${serverDoc.id} (${serverDoc.data().name})`);
  
  // Real-time listener
  serverDoc.ref.onSnapshot((doc) => {
    const data = doc.data();
    console.log(`\n📊 Update Received at ${new Date().toISOString()}:`);
    console.log(`   - Status: ${data.status}`);
    console.log(`   - Bandwidth Used: ${data.bandwidthUsed}`);
    console.log(`   - Last Activity: ${data.lastActivity ? data.lastActivity.toDate() : 'N/A'}`);
  });
}

listenToServer();

// Keep running for 60 seconds then exit
setTimeout(() => {
  console.log('Done testing.');
  process.exit(0);
}, 60000);

