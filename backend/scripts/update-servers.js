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
const realServers = [
  {
    name: 'Singapore SG1',
    flag: '🇸🇬',
    address: '35.240.143.211',
    port: 443,           // WebSocket (Auto/Default)
    tcpPort: 8443,       // Raw TCP
    udpPort: 4434,       // QUIC (UDP)
    uuid: '22b67392-449a-46fa-b33a-f41e08d57fce',
    alterId: 0,
    security: 'auto',
    network: 'ws',
    path: '/vpn',
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
    address: '35.194.102.131',
    port: 443,
    tcpPort: 8443,
    udpPort: 4434,
    uuid: 'bc8756eb-ce08-42b9-8b72-2e8d3b831ce2',
    alterId: 0,
    security: 'auto',
    network: 'ws',
    path: '/vpn',
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
    address: '34.55.189.61',
    port: 443,
    tcpPort: 8443,
    udpPort: 4434,
    uuid: '3f3c63d1-3650-4860-985a-6ea5f481d258',
    alterId: 0,
    security: 'auto',
    network: 'ws',
    path: '/vpn',
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

