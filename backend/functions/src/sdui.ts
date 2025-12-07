/**
 * Server Driven UI (SDUI) Functions
 * - Get Screen Config
 * - Get All Configs
 * - Get App Settings
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// ========== DEFAULT CONFIGS ==========
const DEFAULT_CONFIGS: Record<string, object> = {
  home: {
    screen_id: "home",
    config: {
      type: "dashboard",
      app_bar: {
        title_disconnected: "Not Connected",
        title_connecting: "Connecting...",
        title_connected: "Connected",
      },
      timer_section: {
        show_timer: true,
      },
      main_button: {
        status_text_disconnected: "Tap to Connect",
        status_text_connecting: "Establishing Connection...",
        status_text_connected: "VPN is On",
      },
      location_card: {
        label: "Selected Location",
        recent_label: "Recent Location",
        show_latency_toggle: true,
      },
    },
  },
  popup_startup: {
    screen_id: "popup_startup",
    config: {
      enabled: false,
      display_type: "popup",
      image_url: "",
      image_height: 180,
      title: "Welcome!",
      message: "Welcome to BVPN App",
      is_dismissible: true,
      style: {
        background_color: "#FFFFFF",
        title_color: "#7E57C2",
        title_size: 22,
        message_color: "#666666",
        message_size: 15,
      },
      buttons: [],
    },
  },
  rewards: {
    screen_id: "rewards",
    config: {
      title: "My Rewards",
      payment_methods: ["KBZ Pay", "Wave Pay"],
      min_withdraw_mmk: 20000,
      min_withdraw_usd: 20.0,
      labels: {
        balance_label: "Total Points",
        withdraw_button: "Withdraw Now",
      },
    },
  },
  earn_money: {
    screen_id: "earn_money",
    config: {
      title: "Earn Money",
      reward_per_ad: 30,
      max_ads_per_day: 100,
      currency: "Points",
      labels: {
        balance_label: "Total Points",
        watch_ad_button: "Watch Ad & Earn",
        daily_limit_reached: "Daily Limit Reached",
      },
    },
  },
  settings: {
    screen_id: "settings",
    config: {
      title: "Settings",
      share_text:
        "Check out BVPN App - Secure, Fast & Private VPN!\n\nDownload now: https://play.google.com/store/apps/details?id=com.bvpn",
      version: "V1.0.0",
    },
  },
  contact_us: {
    screen_id: "contact_us",
    config: {
      title: "Contact Us",
      email: "support@bvpn.app",
      telegram: "@bvpn_support",
    },
  },
  about: {
    screen_id: "about",
    config: {
      title: "About",
      app_name: "BVPN App",
      version: "1.0.0",
      description: "The best VPN app for secure and private internet access.",
    },
  },
  splash: {
    screen_id: "splash",
    config: {
      app_name: "BVPN",
      tagline: "Secure & Fast",
      gradient_colors: ["#7E57C2", "#B39DDB"],
      splash_duration_seconds: 3,
    },
  },
};

// ========== GET SCREEN CONFIG ==========
export const getScreenConfig = functions.https.onCall(
  async (request: functions.https.CallableRequest<{ screenId: string }>) => {
    const { screenId } = request.data;

    if (!screenId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "screenId is required"
      );
    }

    const configRef = db.collection("sdui_configs").doc(screenId);
    const configDoc = await configRef.get();

    if (configDoc.exists) {
      return configDoc.data();
    }

    // Return default config if not found in database
    if (DEFAULT_CONFIGS[screenId]) {
      return DEFAULT_CONFIGS[screenId];
    }

    return {
      screen_id: screenId,
      config: {},
    };
  }
);

// ========== GET ALL CONFIGS ==========
export const getAllScreenConfigs = functions.https.onCall(async () => {
  const snapshot = await db.collection("sdui_configs").get();

  const configs: Record<string, object> = { ...DEFAULT_CONFIGS };

  // Override with database configs
  snapshot.docs.forEach((doc) => {
    configs[doc.id] = doc.data();
  });

  return {
    success: true,
    configs,
  };
});

// ========== GET APP SETTINGS ==========
export const getAppSettings = functions.https.onCall(async () => {
  const settingsRef = db.collection("app_settings").doc("global");
  const settingsDoc = await settingsRef.get();

  const defaultSettings = {
    minAppVersion: "1.0.0",
    latestVersion: "1.0.0",
    forceUpdate: false,
    maintenanceMode: false,
    maintenanceMessage: "",
    rewardPerAd: 30,
    maxAdsPerDay: 100,
    minWithdrawMMK: 20000,
    minWithdrawUSD: 20.0,
    paymentMethods: ["KBZ Pay", "Wave Pay"],
    supportEmail: "support@bvpn.app",
    supportTelegram: "@bvpn_support",
    privacyPolicyUrl: "",
    termsOfServiceUrl: "",
  };

  if (!settingsDoc.exists) {
    return {
      success: true,
      settings: defaultSettings,
    };
  }

  const settings = settingsDoc.data();

  return {
    success: true,
    settings: {
      ...defaultSettings,
      ...settings,
    },
  };
});

// ========== CHECK APP VERSION ==========
export const checkAppVersion = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<{ currentVersion: string }>
  ) => {
    const { currentVersion } = request.data;

    if (!currentVersion) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "currentVersion is required"
      );
    }

    const settingsRef = db.collection("app_settings").doc("global");
    const settingsDoc = await settingsRef.get();

    const settings = settingsDoc.exists ? settingsDoc.data() : {};
    const minVersion = settings?.minAppVersion || "1.0.0";
    const latestVersion = settings?.latestVersion || "1.0.0";
    const forceUpdate = settings?.forceUpdate || false;

    // Simple version comparison (assumes semantic versioning)
    const isOutdated = compareVersions(currentVersion, minVersion) < 0;
    const hasUpdate = compareVersions(currentVersion, latestVersion) < 0;

    return {
      success: true,
      currentVersion,
      latestVersion,
      minVersion,
      isOutdated,
      hasUpdate,
      forceUpdate: isOutdated && forceUpdate,
      updateUrl:
        settings?.updateUrl ||
        "https://play.google.com/store/apps/details?id=com.bvpn",
    };
  }
);

// Helper function to compare versions
function compareVersions(v1: string, v2: string): number {
  const parts1 = v1.split(".").map(Number);
  const parts2 = v2.split(".").map(Number);

  for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
    const num1 = parts1[i] || 0;
    const num2 = parts2[i] || 0;

    if (num1 > num2) return 1;
    if (num1 < num2) return -1;
  }

  return 0;
}

