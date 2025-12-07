# BVPN App Backend

Firebase Cloud Functions နဲ့ Firestore ကို အသုံးပြုထားတဲ့ VPN App Backend

## 📁 Project Structure

```
backend/
├── firebase.json          # Firebase configuration
├── firestore.rules        # Firestore security rules
├── firestore.indexes.json # Firestore indexes
├── .firebaserc            # Firebase project settings
├── functions/             # Cloud Functions (TypeScript)
│   ├── src/
│   │   ├── index.ts       # Main entry point
│   │   ├── devices.ts     # Device management
│   │   ├── rewards.ts     # Rewards/Points system
│   │   ├── withdrawals.ts # Withdrawal requests
│   │   ├── servers.ts     # VPN server management
│   │   ├── sdui.ts        # Server Driven UI
│   │   └── admin.ts       # Admin functions
│   ├── package.json
│   └── tsconfig.json
├── public/                # Hosting files
└── scripts/               # Utility scripts
    └── seed-data.js       # Initial data seeder
```

## 🚀 Setup Guide

### 1. Prerequisites
- Node.js 20+
- Firebase CLI (`npm install -g firebase-tools`)
- Google Cloud Project with Firebase enabled

### 2. Login to Firebase
```bash
firebase login
```

### 3. Select Project
```bash
firebase use strategic-volt-341100
# or use your project ID
```

### 4. Install Dependencies
```bash
cd functions
npm install
```

### 5. Enable Required APIs
Enable these APIs in Google Cloud Console:
- [Firestore API](https://console.developers.google.com/apis/api/firestore.googleapis.com/overview?project=strategic-volt-341100)
- [Cloud Functions API](https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=strategic-volt-341100)

### 6. Create Firestore Database
```bash
firebase firestore:databases:create --location=asia-southeast1
```

### 7. Deploy
```bash
# Deploy everything
firebase deploy

# Deploy only functions
firebase deploy --only functions

# Deploy only Firestore rules
firebase deploy --only firestore:rules

# Deploy only hosting
firebase deploy --only hosting
```

### 8. Seed Initial Data
```bash
cd scripts
npm install firebase-admin
node seed-data.js
```

## 📚 Cloud Functions

### Device Functions
| Function | Description |
|----------|-------------|
| `registerDevice` | Register new device or update existing |
| `getDeviceInfo` | Get device information |
| `updateDeviceStatus` | Update online/offline status |
| `updateDataUsage` | Track data usage |

### Rewards Functions
| Function | Description |
|----------|-------------|
| `addAdReward` | Add points for watching ads |
| `getBalance` | Get current balance |
| `getActivityLogs` | Get points history |
| `getRewardsConfig` | Get rewards configuration |

### Withdrawal Functions
| Function | Description |
|----------|-------------|
| `submitWithdrawal` | Submit withdrawal request |
| `getWithdrawalHistory` | Get withdrawal history |
| `cancelWithdrawal` | Cancel pending withdrawal |
| `getWithdrawalConfig` | Get withdrawal settings |

### Server Functions
| Function | Description |
|----------|-------------|
| `getServers` | Get all VPN servers |
| `getServerById` | Get single server |
| `getServerCountries` | Get available countries |
| `generateVmessLink` | Generate V2Ray config |
| `reportServerIssue` | Report server problems |

### SDUI Functions
| Function | Description |
|----------|-------------|
| `getScreenConfig` | Get UI config for screen |
| `getAllScreenConfigs` | Get all UI configs |
| `getAppSettings` | Get app settings |
| `checkAppVersion` | Check for updates |

### Admin Functions
| Function | Description |
|----------|-------------|
| `processWithdrawal` | Approve/reject withdrawal |
| `toggleDeviceBan` | Ban/unban device |
| `adjustBalance` | Add/deduct points |
| `addServer` | Add new VPN server |
| `updateServer` | Update server config |
| `deleteServer` | Delete server |
| `updateSduiConfig` | Update UI config |
| `getDashboardStats` | Get dashboard statistics |
| `getAllDevices` | List all devices |
| `getAllWithdrawals` | List all withdrawals |

## 🗄️ Firestore Collections

### `devices`
```javascript
{
  deviceModel: "Samsung Galaxy S23",
  appVersion: "1.0.0",
  platform: "android",
  balance: 5000,
  status: "online" | "offline" | "banned",
  dataUsage: 12500000,
  country: "Myanmar",
  flag: "🇲🇲",
  ipAddress: "103.25.12.4",
  fcmToken: "...",
  createdAt: Timestamp,
  lastSeen: Timestamp
}
```

### `servers`
```javascript
{
  name: "Singapore SG1",
  flag: "🇸🇬",
  address: "sg1.vpnapp.com",
  port: 443,
  uuid: "a1b2c3d4-...",
  alterId: 0,
  security: "auto",
  network: "ws",
  path: "/vpn",
  tls: true,
  country: "Singapore",
  status: "online" | "offline" | "maintenance",
  isPremium: false,
  load: 45
}
```

### `withdrawals`
```javascript
{
  deviceId: "d1b2-4c3a-9f8e",
  amount: 5000,
  points: 5000,
  method: "KBZ Pay",
  accountNumber: "09123456789",
  accountName: "Mg Mg",
  currency: "MMK",
  status: "pending" | "approved" | "rejected",
  createdAt: Timestamp,
  processedAt: Timestamp,
  processedBy: "admin-001"
}
```

### `activity_logs`
```javascript
{
  deviceId: "d1b2-4c3a-9f8e",
  type: "ad_reward" | "withdrawal" | "admin_adjustment",
  description: "Watched Reward Ad",
  amount: 30,
  timestamp: Timestamp
}
```

## 🔧 Local Development

### Run Emulators
```bash
firebase emulators:start
```

Emulator URLs:
- Functions: http://localhost:5001
- Firestore: http://localhost:8080
- Hosting: http://localhost:5000
- Emulator UI: http://localhost:4000

### Watch for Changes
```bash
cd functions
npm run build:watch
```

## 📱 Flutter Integration

Add to `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^3.0.0
  cloud_firestore: ^5.0.0
  cloud_functions: ^5.0.0
```

Call functions:
```dart
final functions = FirebaseFunctions.instance;

// Register device
final result = await functions
    .httpsCallable('registerDevice')
    .call({
      'deviceId': 'unique-device-id',
      'deviceModel': 'Samsung Galaxy S23',
      'appVersion': '1.0.0',
    });

print(result.data);
```

## 📄 License

MIT License

