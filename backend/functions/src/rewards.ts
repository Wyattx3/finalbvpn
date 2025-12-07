/**
 * Rewards Functions
 * - Add Ad Reward
 * - Add Balance (Bonus)
 * - Get Balance
 * - Get Activity Logs
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// ========== CONSTANTS ==========
const REWARD_PER_AD = 30; // Points per ad
const TIME_BONUS_SECONDS = 7200; // 2 hours VPN time
const MAX_ADS_PER_DAY = 100;
const COOLDOWN_AFTER_ADS = 10; // Cooldown after 10 ads
const COOLDOWN_MINUTES = 10;

// ========== INTERFACES ==========
interface ActivityLog {
  deviceId: string;
  type: "ad_reward" | "withdrawal" | "admin_adjustment" | "bonus";
  description: string;
  amount: number;
  timestamp: admin.firestore.Timestamp;
}

// ========== ADD AD REWARD ==========
export const addAdReward = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<{
      deviceId: string;
      adType?: string;
    }>
  ) => {
    const { deviceId, adType } = request.data;

    if (!deviceId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "deviceId is required"
      );
    }

    const deviceRef = db.collection("devices").doc(deviceId);

    // Use transaction for atomic update
    const result = await db.runTransaction(async (transaction) => {
      const deviceDoc = await transaction.get(deviceRef);

      if (!deviceDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Device not found");
      }

      const deviceData = deviceDoc.data();

      // Check if device is banned
      if (deviceData?.status === "banned") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Device is banned"
        );
      }

      const newBalance = (deviceData?.balance || 0) + REWARD_PER_AD;

      // Update device balance
      transaction.update(deviceRef, {
        balance: newBalance,
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Log the activity
      const logRef = db.collection("activity_logs").doc();
      const logData: ActivityLog = {
        deviceId,
        type: "ad_reward",
        description: `Watched ${adType || "Reward"} Ad`,
        amount: REWARD_PER_AD,
        timestamp: admin.firestore.Timestamp.now(),
      };
      transaction.set(logRef, logData);

      return {
        newBalance,
        pointsEarned: REWARD_PER_AD,
        timeBonusSeconds: TIME_BONUS_SECONDS,
      };
    });

    return {
      success: true,
      ...result,
      message: `+${REWARD_PER_AD} Points Earned!`,
    };
  }
);

// ========== GET BALANCE ==========
export const getBalance = functions.https.onCall(
  async (request: functions.https.CallableRequest<{ deviceId: string }>) => {
    const { deviceId } = request.data;

    if (!deviceId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "deviceId is required"
      );
    }

    const deviceRef = db.collection("devices").doc(deviceId);
    const deviceDoc = await deviceRef.get();

    if (!deviceDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Device not found");
    }

    const deviceData = deviceDoc.data();

    return {
      success: true,
      balance: deviceData?.balance || 0,
      balanceMMK: deviceData?.balance || 0,
      balanceUSD: ((deviceData?.balance || 0) / 4500).toFixed(2),
    };
  }
);

// ========== GET ACTIVITY LOGS ==========
export const getActivityLogs = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<{
      deviceId: string;
      limit?: number;
      type?: string;
    }>
  ) => {
    const { deviceId, limit = 50, type } = request.data;

    if (!deviceId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "deviceId is required"
      );
    }

    let query = db
      .collection("activity_logs")
      .where("deviceId", "==", deviceId)
      .orderBy("timestamp", "desc")
      .limit(limit);

    if (type) {
      query = db
        .collection("activity_logs")
        .where("deviceId", "==", deviceId)
        .where("type", "==", type)
        .orderBy("timestamp", "desc")
        .limit(limit);
    }

    const snapshot = await query.get();

    const logs = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate?.()?.toISOString() || null,
    }));

    return {
      success: true,
      logs,
      count: logs.length,
    };
  }
);

// ========== GET APP SETTINGS (Rewards Config) ==========
export const getRewardsConfig = functions.https.onCall(async () => {
  const settingsRef = db.collection("app_settings").doc("global");
  const settingsDoc = await settingsRef.get();

  if (!settingsDoc.exists) {
    // Return default settings
    return {
      success: true,
      config: {
        rewardPerAd: REWARD_PER_AD,
        maxAdsPerDay: MAX_ADS_PER_DAY,
        cooldownAfterAds: COOLDOWN_AFTER_ADS,
        cooldownMinutes: COOLDOWN_MINUTES,
        timeBonusSeconds: TIME_BONUS_SECONDS,
      },
    };
  }

  const settings = settingsDoc.data();

  return {
    success: true,
    config: {
      rewardPerAd: settings?.rewardPerAd || REWARD_PER_AD,
      maxAdsPerDay: settings?.maxAdsPerDay || MAX_ADS_PER_DAY,
      cooldownAfterAds: settings?.cooldownAfterAds || COOLDOWN_AFTER_ADS,
      cooldownMinutes: settings?.cooldownMinutes || COOLDOWN_MINUTES,
      timeBonusSeconds: settings?.timeBonusSeconds || TIME_BONUS_SECONDS,
    },
  };
});

