#!/bin/bash

# BVPN Server Setup Script
# Installs V2Ray, configures ports (TCP/UDP/WS), and sets up usage reporting.
# Usage: sudo ./setup_v2ray.sh <SERVER_UUID> <FIREBASE_PROJECT_ID>

UUID=$1
PROJECT_ID=$2

if [ -z "$UUID" ]; then
  echo "Error: UUID is required"
  echo "Usage: sudo ./setup_v2ray.sh <SERVER_UUID> <FIREBASE_PROJECT_ID>"
  exit 1
fi

echo "🚀 Starting BVPN Server Setup..."
echo "UUID: $UUID"

# 1. Install Basic Tools
apt-get update
apt-get install -y curl unzip nodejs npm git

# 2. Install V2Ray
echo "Installing V2Ray..."
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# 3. Configure V2Ray
echo "Configuring V2Ray..."
cat > /usr/local/etc/v2ray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "stats": {},
  "api": {
    "tag": "api",
    "services": [
      "StatsService"
    ]
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },
  "inbounds": [
    {
      "tag": "ws-in",
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0,
            "email": "user_ws"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/"
        }
      }
    },
    {
      "tag": "tcp-in",
      "port": 8443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0,
            "email": "user_tcp"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      }
    },
    {
      "tag": "quic-in",
      "port": 4434,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0,
            "email": "user_quic"
          }
        ]
      },
      "streamSettings": {
        "network": "quic",
        "quicSettings": {
          "security": "none",
          "key": "",
          "header": {
            "type": "none"
          }
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ],
  "routing": {
    "rules": [
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      }
    ]
  }
}
EOF

# 4. Restart V2Ray
systemctl restart v2ray
systemctl enable v2ray

# 5. Setup Firebase Reporter
echo "Setting up Usage Reporter..."
mkdir -p /opt/bvpn-reporter
cd /opt/bvpn-reporter

# Create package.json
cat > package.json <<EOF
{
  "name": "bvpn-reporter",
  "version": "1.0.0",
  "dependencies": {
    "firebase-admin": "^11.11.0",
    "@grpc/grpc-js": "^1.9.0",
    "google-protobuf": "^3.21.2",
    "v2ray-client": "^1.0.0"
  }
}
EOF

# Install dependencies (simplified for script)
npm install firebase-admin @grpc/grpc-js google-protobuf

# Create Reporter Script
cat > index.js <<EOF
const admin = require('firebase-admin');
const { exec } = require('child_process');

// Initialize Firebase
// NOTE: Ensure firebase-service-account.json is present!
try {
    const serviceAccount = require('./firebase-service-account.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log('Firebase initialized');
} catch (e) {
    console.error('Firebase init failed:', e.message);
    process.exit(1);
}

const db = admin.firestore();
const SERVER_UUID = '$UUID'; // Using UUID as Server ID for lookup

// Function to get V2Ray Stats via v2ctl (easier than gRPC node client for simple stats)
function getStats() {
    exec('/usr/local/bin/v2ray api stats --server=127.0.0.1:10085', (error, stdout, stderr) => {
        if (error) {
            console.error('Error fetching stats:', error);
            return;
        }
        
        // Parse Output
        // Example: user>>>user_ws>>>uplink 1024
        const lines = stdout.split('\n');
        let totalUp = 0;
        let totalDown = 0;

        lines.forEach(line => {
            if (line.includes('uplink')) {
                const val = parseInt(line.split(/\s+/).pop());
                if (!isNaN(val)) totalUp += val;
            }
            if (line.includes('downlink')) {
                const val = parseInt(line.split(/\s+/).pop());
                if (!isNaN(val)) totalDown += val;
            }
        });

        console.log(\`Stats - Up: \${totalUp}, Down: \${totalDown}\`);
        updateFirebase(totalUp, totalDown);
    });
}

async function updateFirebase(up, down) {
    try {
        // Find server by UUID
        const serversSnapshot = await db.collection('servers').where('uuid', '==', SERVER_UUID).get();
        
        if (serversSnapshot.empty) {
            console.log('Server not found in Firestore');
            return;
        }

        const serverDoc = serversSnapshot.docs[0];
        await serverDoc.ref.update({
            'bandwidthUsed': up + down,
            'uploadUsed': up,
            'downloadUsed': down,
            'lastActivity': admin.firestore.FieldValue.serverTimestamp(),
            'status': 'online'
        });
        console.log('Firebase updated');
    } catch (e) {
        console.error('Firebase update error:', e);
    }
}

// Run every 10 seconds
setInterval(getStats, 10000);
getStats();
EOF

echo "✅ Setup Complete!"
echo "⚠️ IMPORTANT: Upload your 'firebase-service-account.json' to /opt/bvpn-reporter/"
echo "Then run: cd /opt/bvpn-reporter && node index.js"

