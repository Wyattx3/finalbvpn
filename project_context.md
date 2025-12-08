# Project Context: BVPN (Suf Fhoke VPN)

## 1. Project Overview
This is a V2Ray-based VPN application with a built-in reward system. Users can earn points (likely by watching ads) and withdraw them via local payment methods (KBZ Pay, Wave Pay). The app features a Server Driven UI (SDUI) system, allowing dynamic updates to the UI without app store releases.

## 2. Architecture & Tech Stack

### Mobile App (Flutter)
- **Path:** `/` (Root)
- **Framework:** Flutter (Dart)
- **State Management:** `ValueNotifier` + `ChangeNotifier` (ThemeNotifier)
- **VPN Protocol:** V2Ray (VMess via TCP/WS/QUIC)
    - **Plugin:** `flutter_v2ray` (Wraps libv2ray core for real connections)
    - **Config:** `lib/utils/v2ray_config.dart` generates standard V2Ray JSON configs.
- **Key Services:**
    - `FirebaseService`: Handles Auth, Firestore, and Functions interactions.
    - `SduiService`: Manages Server Driven UI configurations with real-time updates.
    - `VpnSpeedService`: Monitors connection speed, Ping, and Real-time Server Load via Firestore.
- **UI:** Material 3 with custom theming (Purple/Dark/Light).

### Admin Dashboard (Next.js)
- **Path:** `/admin-dashboard`
- **Framework:** Next.js 16 (App Router), React 19
- **Styling:** Tailwind CSS
- **Purpose:** Manage users, servers, view analytics, and update SDUI configurations.
- **Real-time Monitoring:**
    - **Users Page:** Uses `useRealtimeDevices` hook to show live data usage and online status.
    - **Servers Page:** Uses `useRealtimeServers` hook to show live bandwidth usage and server status.

### Backend (Firebase)
- **Path:** `/backend`
- **Services:**
    - **Firestore:** Database for all app data.
    - **Cloud Functions:** Server-side logic (Node.js 20).
    - **Authentication:** Anonymous auth (device ID based) & Admin auth.
- **Security Rules:** `firestore.rules` defines access control (e.g., `sdui_configs` is public read).

### Infrastructure (Google Cloud)
- **Server:** Ubuntu VM with V2Ray.
- **Setup Script:** `infrastructure/setup_v2ray.sh` automates installation.
- **Protocols Supported:**
    - **Auto (WebSocket):** Port 443 (VMess/VLESS)
    - **TCP:** Port 8443 (VMess/VLESS over TCP)
    - **UDP (QUIC):** Port 4434 (VMess/VLESS over QUIC)
- **Monitoring:** `bvpn-reporter` (Node.js) runs on the server to push real-time bandwidth usage to Firestore.

## 3. Key Features

### Server Driven UI (SDUI)
Allows remote configuration of:
- **Screens:** Onboarding, Home, Rewards, Splash, Settings, etc.
- **Elements:** Texts, Colors, Button labels, Feature toggles.
- **Logic:** Maintenance mode, Popups.
- **Config Location:** Firestore collection `sdui_configs`.

### Reward System
- Users earn points (configured in `app_settings` / `earn_money` config).
- Withdrawal options: KBZ Pay, Wave Pay.
- Transactions tracked in Firestore.

### VPN Connectivity
- Uses `flutter_v2ray` plugin for **Real V2Ray Core** integration.
- **Protocols:** User can select TCP, UDP, or Auto in Settings.
- **Servers:** Managed in `servers` collection.
- **Stats:** Displays Ping (latency), Download/Upload Speed, and Server Load.

### Device Management
- **Identity:** Devices identified by `android_id` / unique ID.
- **Ban System:** Real-time banning capability. Banned devices see a `BannedScreen`.
- **Heartbeat:** Devices send a heartbeat every 2 minutes to indicate online status.

## 4. Data Schema (Firestore)
- `servers`: VPN server configurations (includes `bandwidthUsed`, `latency`).
- `app_settings`: Global configs (version, rewards, maintenance).
- `sdui_configs`: UI definitions for the app.
- `devices`: Registered device info.
- `admins`: Admin user accounts.
- `activity_logs` / `login_activity`: User activity tracking.
- `withdrawals`: Payment requests.

## 5. Development Setup
- **Flutter:** `flutter run`
- **Admin:** `cd admin-dashboard && npm run dev`
- **Firebase:** `firebase emulators:start` (for local backend testing)
- **Server Setup:** Run `infrastructure/setup_v2ray.sh` on a fresh Ubuntu VM.
