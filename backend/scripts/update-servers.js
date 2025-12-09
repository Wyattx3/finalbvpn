/**
 * Update Firebase with Real V2Ray VPN Servers
 * Run: node scripts/update-servers.js
 */

const admin = require('firebase-admin');

// Initialize with default credentials
admin.initializeApp({
  projectId: 'strategic-volt-341100'
});

const db = admin.firestore();

// Real V2Ray VPN Servers on Google Cloud
// Supports: WebSocket (443), TCP (8443), QUIC/UDP (4434)
// Real V2Ray VPN Servers on Google Cloud
// Supports: WebSocket (443), TCP (8443), QUIC/UDP (4434)
const realServers = [
  {
    name: 'Singapore SG1',
    flag: '🇸🇬',
    countryCode: 'SG',
    address: '35.247.157.141',
    port: 443,
    tcpPort: 8443,
    udpPort: 4434,
    uuid: 'b0072dd6-5d4d-45f7-a462-dc9bc53d23a9',
    alterId: 0,
    security: 'auto',
    network: 'ws',
    path: '/',
    tls: false,
    country: 'Singapore',
    status: 'online',
    isPremium: false,
    load: 0,
    bandwidthUsed: 0,
    totalConnections: 0,
    supportsTcp: true,
    supportsUdp: true,
  },
  {
    name: 'Singapore SG2',
    flag: '🇸🇬',
    countryCode: 'SG',
    address: '35.240.143.211',
    port: 443,
    tcpPort: 8443,
    udpPort: 4434,
    uuid: '23a610b7-6dd7-482e-af6c-f43f9d2b51bb',
    alterId: 0,
    security: 'auto',
    network: 'ws',
    path: '/',
    tls: false,
    country: 'Singapore',
    status: 'online',
    isPremium: false,
    load: 0,
    bandwidthUsed: 0,
    totalConnections: 0,
    supportsTcp: true,
    supportsUdp: true,
  },
  {
    name: 'Japan JP1',
    flag: '🇯🇵',
    countryCode: 'JP',
    address: '136.110.71.24',
    port: 443,
    tcpPort: 8443,
    udpPort: 4434,
    uuid: 'ced4dcef-3154-4107-a06c-5bc7f8f017ee',
    alterId: 0,
    security: 'auto',
    network: 'ws',
    path: '/',
    tls: false,
    country: 'Japan',
    status: 'online',
    isPremium: false,
    load: 0,
    bandwidthUsed: 0,
    totalConnections: 0,
    supportsTcp: true,
    supportsUdp: true,
  },
  {
    name: 'United States US1',
    flag: '🇺🇸',
    countryCode: 'US',
    address: '35.226.3.239',
    port: 443,
    tcpPort: 8443,
    udpPort: 4434,
    uuid: 'e5fcf3ce-15cc-448a-a70c-ecb9ba614c16',
    alterId: 0,
    security: 'auto',
    network: 'ws',
    path: '/',
    tls: false,
    country: 'United States',
    status: 'online',
    isPremium: false,
    load: 0,
    bandwidthUsed: 0,
    totalConnections: 0,
    supportsTcp: true,
    supportsUdp: true,
  }
];

async function clearOldServers() {
  console.log('🗑️ Clearing old servers...');
  const snapshot = await db.collection('servers').get();
  
  const batch = db.batch();
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  
  await batch.commit();
  console.log(`✅ Cleared ${snapshot.docs.length} old servers`);
}

async function addRealServers() {
  console.log('🖥️ Adding real V2Ray servers...');
  const batch = db.batch();
  
  for (const server of realServers) {
    const ref = db.collection('servers').doc();
    batch.set(ref, {
      ...server,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  
  await batch.commit();
  console.log(`✅ Added ${realServers.length} real servers`);
}

async function main() {
  console.log('🚀 Updating Firebase with real VPN servers...\n');
  
  try {
    await clearOldServers();
    await addRealServers();
    
    console.log('\n✨ Successfully updated servers!');
    console.log('\n📋 Real Servers:');
    realServers.forEach((s, i) => {
      console.log(`   ${i+1}. ${s.flag} ${s.name}: ${s.address}:${s.port}`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

main();

