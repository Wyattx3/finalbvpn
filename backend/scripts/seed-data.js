/**
 * BVPN App - Initial Data Seed Script
 * Run this script to populate initial data in Firestore
 * 
 * Usage: 
 * 1. First run: firebase login
 * 2. Then run: node scripts/seed-data.js
 */

const admin = require('firebase-admin');

// Initialize with default credentials (uses GOOGLE_APPLICATION_CREDENTIALS or gcloud auth)
admin.initializeApp({
  projectId: 'strategic-volt-341100'
});

const db = admin.firestore();

// ========== SEED DATA ==========

const appSettings = {
  minAppVersion: '1.0.0',
  latestVersion: '1.0.0',
  forceUpdate: false,
  maintenanceMode: false,
  maintenanceMessage: '',
  rewardPerAd: 30,
  maxAdsPerDay: 100,
  cooldownAfterAds: 10,
  cooldownMinutes: 10,
  timeBonusSeconds: 7200,
  minWithdrawMMK: 20000,
  minWithdrawUSD: 20.0,
  paymentMethods: ['KBZ Pay', 'Wave Pay'],
  supportEmail: 'support@bvpn.app',
  supportTelegram: '@bvpn_support',
  privacyPolicyUrl: '',
  termsOfServiceUrl: '',
  updatedAt: admin.firestore.FieldValue.serverTimestamp()
};

const sampleServers = [
  {
    name: 'Singapore SG1',
    flag: '🇸🇬',
    address: '35.247.157.141',
    port: 443,
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
    bandwidthUsed: 0
  }
];

const sduiConfigs = {
  home: {
    screen_id: 'home',
    config: {
      type: 'dashboard',
      app_bar: {
        title_disconnected: 'Not Connected',
        title_connecting: 'Connecting...',
        title_connected: 'Connected'
      },
      timer_section: { show_timer: true },
      main_button: {
        status_text_disconnected: 'Tap to Connect',
        status_text_connecting: 'Establishing Connection...',
        status_text_connected: 'VPN is On'
      },
      location_card: {
        label: 'Selected Location',
        recent_label: 'Recent Location',
        show_latency_toggle: true
      }
    }
  },
  popup_startup: {
    screen_id: 'popup_startup',
    config: {
      enabled: false,
      display_type: 'popup',
      image_url: '',
      image_height: 180,
      title: 'Welcome!',
      message: 'Welcome to BVPN App',
      is_dismissible: true,
      style: {
        background_color: '#FFFFFF',
        title_color: '#7E57C2',
        title_size: 22,
        message_color: '#666666',
        message_size: 15
      },
      buttons: []
    }
  },
  rewards: {
    screen_id: 'rewards',
    config: {
      title: 'My Rewards',
      payment_methods: ['KBZ Pay', 'Wave Pay'],
      min_withdraw_mmk: 20000,
      min_withdraw_usd: 20.0,
      labels: {
        balance_label: 'Total Points',
        withdraw_button: 'Withdraw Now'
      }
    }
  },
  earn_money: {
    screen_id: 'earn_money',
    config: {
      title: 'Earn Money',
      reward_per_ad: 30,
      max_ads_per_day: 100,
      currency: 'Points',
      labels: {
        balance_label: 'Total Points',
        watch_ad_button: 'Watch Ad & Earn',
        daily_limit_reached: 'Daily Limit Reached'
      }
    }
  },
  splash: {
    screen_id: 'splash',
    config: {
      app_name: 'BVPN',
      tagline: 'Secure & Fast',
      gradient_colors: ['#7E57C2', '#B39DDB'],
      splash_duration_seconds: 3
    }
  }
};

// Admin user (you should replace this with your actual admin ID)
const adminUsers = [
  {
    id: 'admin-001',
    email: 'admin@bvpn.app',
    name: 'Admin',
    role: 'super_admin',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  }
];

// ========== SEED FUNCTIONS ==========

async function seedAppSettings() {
  console.log('📝 Seeding app settings...');
  await db.collection('app_settings').doc('global').set(appSettings);
  console.log('✅ App settings seeded');
}

async function seedServers() {
  console.log('🖥️ Seeding servers...');
  const batch = db.batch();
  
  for (const server of sampleServers) {
    const ref = db.collection('servers').doc();
    batch.set(ref, {
      ...server,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  
  await batch.commit();
  console.log(`✅ ${sampleServers.length} servers seeded`);
}

async function seedSduiConfigs() {
  console.log('🎨 Seeding SDUI configs...');
  const batch = db.batch();
  
  for (const [screenId, config] of Object.entries(sduiConfigs)) {
    const ref = db.collection('sdui_configs').doc(screenId);
    batch.set(ref, {
      ...config,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  
  await batch.commit();
  console.log(`✅ ${Object.keys(sduiConfigs).length} SDUI configs seeded`);
}

async function seedAdmins() {
  console.log('👤 Seeding admin users...');
  const batch = db.batch();
  
  for (const adminUser of adminUsers) {
    const ref = db.collection('admins').doc(adminUser.id);
    batch.set(ref, adminUser);
  }
  
  await batch.commit();
  console.log(`✅ ${adminUsers.length} admin users seeded`);
}

// ========== MAIN ==========

async function main() {
  console.log('🚀 Starting BVPN Database Seed...\n');
  
  try {
    await seedAppSettings();
    await seedServers();
    await seedSduiConfigs();
    await seedAdmins();
    
    console.log('\n✨ All data seeded successfully!');
    console.log('\n📋 Summary:');
    console.log('   - App Settings: 1 document');
    console.log(`   - Servers: ${sampleServers.length} documents`);
    console.log(`   - SDUI Configs: ${Object.keys(sduiConfigs).length} documents`);
    console.log(`   - Admins: ${adminUsers.length} documents`);
    
  } catch (error) {
    console.error('❌ Error seeding data:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

main();

