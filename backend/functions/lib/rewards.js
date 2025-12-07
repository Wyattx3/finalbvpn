"use strict";
/**
 * Rewards Functions
 * - Add Ad Reward
 * - Add Balance (Bonus)
 * - Get Balance
 * - Get Activity Logs
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getRewardsConfig = exports.getActivityLogs = exports.getBalance = exports.addAdReward = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
// ========== CONSTANTS ==========
const REWARD_PER_AD = 30; // Points per ad
const TIME_BONUS_SECONDS = 7200; // 2 hours VPN time
const MAX_ADS_PER_DAY = 100;
const COOLDOWN_AFTER_ADS = 10; // Cooldown after 10 ads
const COOLDOWN_MINUTES = 10;
// ========== ADD AD REWARD ==========
exports.addAdReward = functions.https.onCall(async (request) => {
    const { deviceId, adType } = request.data;
    if (!deviceId) {
        throw new functions.https.HttpsError("invalid-argument", "deviceId is required");
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
            throw new functions.https.HttpsError("permission-denied", "Device is banned");
        }
        const newBalance = (deviceData?.balance || 0) + REWARD_PER_AD;
        // Update device balance
        transaction.update(deviceRef, {
            balance: newBalance,
            lastSeen: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Log the activity
        const logRef = db.collection("activity_logs").doc();
        const logData = {
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
});
// ========== GET BALANCE ==========
exports.getBalance = functions.https.onCall(async (request) => {
    const { deviceId } = request.data;
    if (!deviceId) {
        throw new functions.https.HttpsError("invalid-argument", "deviceId is required");
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
});
// ========== GET ACTIVITY LOGS ==========
exports.getActivityLogs = functions.https.onCall(async (request) => {
    const { deviceId, limit = 50, type } = request.data;
    if (!deviceId) {
        throw new functions.https.HttpsError("invalid-argument", "deviceId is required");
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
});
// ========== GET APP SETTINGS (Rewards Config) ==========
exports.getRewardsConfig = functions.https.onCall(async () => {
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
//# sourceMappingURL=rewards.js.map