// Seed initial data to Firestore for Suk Fhyoke VPN App
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const keyPath = path.join(__dirname, 'firebase-admin-key.json');
const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'strategic-volt-341100',
});

const db = admin.firestore();

async function seedData() {
  console.log('🚀 Starting data seeding...\n');

  // 1. Seed App Settings
  console.log('📝 Seeding app_settings...');
  await db.collection('app_settings').doc('global').set({
    rewardPerAd: 30,
    maxAdsPerDay: 100,
    timeBonusSeconds: 7200,
    cooldownAdsCount: 10,     // Cooldown after every N ads
    cooldownMinutes: 10,      // Cooldown duration in minutes
    minWithdrawMMK: 20000,
    paymentMethods: ['KBZ Pay', 'Wave Pay', 'CB Pay'],
    appVersion: '1.0.0',
    maintenanceMode: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('✅ App settings seeded\n');

  // 2. Seed VPN Servers
  console.log('📝 Seeding servers...');
  const servers = [
    {
      name: 'Singapore Premium',
      country: 'Singapore',
      flag: '🇸🇬',
      host: 'sg1.bvpn.example.com',
      port: 443,
      protocol: 'vmess',
      status: 'online',
      load: 45,
      latency: 35,
      isPremium: false,
    },
    {
      name: 'Japan Tokyo',
      country: 'Japan',
      flag: '🇯🇵',
      host: 'jp1.bvpn.example.com',
      port: 443,
      protocol: 'vmess',
      status: 'online',
      load: 60,
      latency: 55,
      isPremium: false,
    },
    {
      name: 'US West',
      country: 'United States',
      flag: '🇺🇸',
      host: 'us1.bvpn.example.com',
      port: 443,
      protocol: 'vmess',
      status: 'online',
      load: 30,
      latency: 180,
      isPremium: false,
    },
    {
      name: 'Germany Frankfurt',
      country: 'Germany',
      flag: '🇩🇪',
      host: 'de1.bvpn.example.com',
      port: 443,
      protocol: 'vmess',
      status: 'online',
      load: 25,
      latency: 200,
      isPremium: true,
    },
    {
      name: 'Thailand Bangkok',
      country: 'Thailand',
      flag: '🇹🇭',
      host: 'th1.bvpn.example.com',
      port: 443,
      protocol: 'vmess',
      status: 'online',
      load: 50,
      latency: 25,
      isPremium: false,
    },
  ];

  for (const server of servers) {
    await db.collection('servers').add({
      ...server,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  console.log(`✅ ${servers.length} servers seeded\n`);

  // 3. Seed SDUI Configs
  console.log('📝 Seeding sdui_configs...');
  const sduiConfigs = {
    splash: {
      app_name: 'Suk Fhyoke VPN',
      tagline: 'Secure & Fast VPN',
      gradient_colors: ['#7E57C2', '#B39DDB'],
      splash_duration_seconds: 3,
    },
    home: {
      app_bar: {
        title_disconnected: 'Not Connected',
        title_connecting: 'Connecting...',
        title_connected: 'Protected',
      },
      timer_section: { show_timer: true },
      main_button: {
        status_text_disconnected: 'Tap to Connect',
        status_text_connecting: 'Establishing Connection...',
        status_text_connected: 'VPN is On',
      },
      location_card: {
        label: 'Selected Location',
        recent_label: 'Recent Location',
        show_latency_toggle: true,
      },
    },
    rewards: {
      title: 'My Rewards',
      payment_methods: ['KBZ Pay', 'Wave Pay', 'CB Pay'],
      min_withdraw_mmk: 20000,
      labels: {
        balance_label: 'Total Points',
        withdraw_button: 'Withdraw Now',
      },
    },
    earn_money: {
      title: 'Earn Points',
      reward_per_ad: 30,
      max_ads_per_day: 100,
      description: 'Watch ads to earn points!',
    },
  };

  for (const [screenId, config] of Object.entries(sduiConfigs)) {
    await db.collection('sdui_configs').doc(screenId).set({
      screen_id: screenId,
      config,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  console.log(`✅ ${Object.keys(sduiConfigs).length} SDUI configs seeded\n`);

  // 4. Seed Test Devices
  console.log('📝 Seeding test devices...');
  const testDevices = [
    {
      deviceId: 'test-device-001',
      deviceModel: 'Samsung Galaxy S23',
      platform: 'android',
      appVersion: '1.0.0',
      status: 'online',
      balance: 15000,
      country: 'Myanmar',
      flag: '🇲🇲',
      ipAddress: '103.45.67.89',
      dataUsage: 1024 * 1024 * 500, // 500 MB
    },
    {
      deviceId: 'test-device-002',
      deviceModel: 'iPhone 15 Pro',
      platform: 'ios',
      appVersion: '1.0.0',
      status: 'offline',
      balance: 25000,
      country: 'Myanmar',
      flag: '🇲🇲',
      ipAddress: '103.45.67.90',
      dataUsage: 1024 * 1024 * 800, // 800 MB
    },
    {
      deviceId: 'test-device-003',
      deviceModel: 'Xiaomi 14',
      platform: 'android',
      appVersion: '1.0.0',
      status: 'online',
      balance: 5000,
      country: 'Thailand',
      flag: '🇹🇭',
      ipAddress: '202.44.55.66',
      dataUsage: 1024 * 1024 * 200, // 200 MB
    },
  ];

  for (const device of testDevices) {
    await db.collection('devices').doc(device.deviceId).set({
      ...device,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Add some activity logs for each device
    await db.collection('activity_logs').add({
      deviceId: device.deviceId,
      type: 'ad_reward',
      description: 'Watched reward ad',
      amount: 30,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  console.log(`✅ ${testDevices.length} test devices seeded\n`);

  // 5. Seed Test Withdrawals
  console.log('📝 Seeding test withdrawals...');
  const withdrawals = [
    {
      deviceId: 'test-device-001',
      points: 10000,
      amount: 10000,
      method: 'KBZ Pay',
      accountNumber: '09123456789',
      accountName: 'Aung Aung',
      status: 'pending',
    },
    {
      deviceId: 'test-device-002',
      points: 20000,
      amount: 20000,
      method: 'Wave Pay',
      accountNumber: '09987654321',
      accountName: 'Maung Maung',
      status: 'approved',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  for (const withdrawal of withdrawals) {
    await db.collection('withdrawals').add({
      ...withdrawal,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  console.log(`✅ ${withdrawals.length} test withdrawals seeded\n`);

  // 6. Seed Admin
  console.log('📝 Seeding admin account...');
  await db.collection('admins').doc('admin-001').set({
    email: 'admin@bvpn.com',
    name: 'Admin',
    role: 'super_admin',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('✅ Admin account seeded\n');

  console.log('🎉 All data seeded successfully!');
  process.exit(0);
}

seedData().catch((error) => {
  console.error('❌ Error seeding data:', error);
  process.exit(1);
});

