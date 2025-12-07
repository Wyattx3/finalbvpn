"use strict";
/**
 * Withdrawal Functions
 * - Submit Withdrawal Request
 * - Get Withdrawal History
 * - Cancel Withdrawal (if pending)
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
exports.getWithdrawalConfig = exports.cancelWithdrawal = exports.getWithdrawalHistory = exports.submitWithdrawal = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
// ========== CONSTANTS ==========
const MIN_WITHDRAW_MMK = 20000;
const MIN_WITHDRAW_USD = 20;
const MMK_TO_USD_RATE = 4500;
// ========== SUBMIT WITHDRAWAL ==========
exports.submitWithdrawal = functions.https.onCall(async (request) => {
    const { deviceId, amount, method, accountNumber, accountName, currency = "MMK" } = request.data;
    // Validation
    if (!deviceId || !amount || !method || !accountNumber || !accountName) {
        throw new functions.https.HttpsError("invalid-argument", "All fields are required");
    }
    // Check minimum amount
    const minAmount = currency === "USD" ? MIN_WITHDRAW_USD : MIN_WITHDRAW_MMK;
    if (amount < minAmount) {
        throw new functions.https.HttpsError("invalid-argument", `Minimum withdrawal is ${minAmount} ${currency}`);
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
        const currentBalance = deviceData?.balance || 0;
        // Calculate points needed (1 Point = 1 MMK)
        const pointsNeeded = currency === "USD" ? amount * MMK_TO_USD_RATE : amount;
        if (currentBalance < pointsNeeded) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient balance");
        }
        // Deduct balance
        transaction.update(deviceRef, {
            balance: currentBalance - pointsNeeded,
        });
        // Create withdrawal request
        const withdrawalRef = db.collection("withdrawals").doc();
        const withdrawalData = {
            deviceId,
            amount,
            points: pointsNeeded,
            method,
            accountNumber,
            accountName,
            currency,
            status: "pending",
            createdAt: admin.firestore.Timestamp.now(),
        };
        transaction.set(withdrawalRef, withdrawalData);
        // Log activity
        const logRef = db.collection("activity_logs").doc();
        transaction.set(logRef, {
            deviceId,
            type: "withdrawal",
            description: `Withdrawal Request (${method})`,
            amount: -pointsNeeded,
            timestamp: admin.firestore.Timestamp.now(),
        });
        return {
            withdrawalId: withdrawalRef.id,
            pointsDeducted: pointsNeeded,
            newBalance: currentBalance - pointsNeeded,
        };
    });
    return {
        success: true,
        ...result,
        message: "Withdrawal request submitted successfully",
    };
});
// ========== GET WITHDRAWAL HISTORY ==========
exports.getWithdrawalHistory = functions.https.onCall(async (request) => {
    const { deviceId, limit = 20, status } = request.data;
    if (!deviceId) {
        throw new functions.https.HttpsError("invalid-argument", "deviceId is required");
    }
    let query = db
        .collection("withdrawals")
        .where("deviceId", "==", deviceId)
        .orderBy("createdAt", "desc")
        .limit(limit);
    if (status) {
        query = db
            .collection("withdrawals")
            .where("deviceId", "==", deviceId)
            .where("status", "==", status)
            .orderBy("createdAt", "desc")
            .limit(limit);
    }
    const snapshot = await query.get();
    const withdrawals = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
        processedAt: doc.data().processedAt?.toDate?.()?.toISOString() || null,
    }));
    return {
        success: true,
        withdrawals,
        count: withdrawals.length,
    };
});
// ========== CANCEL WITHDRAWAL ==========
exports.cancelWithdrawal = functions.https.onCall(async (request) => {
    const { deviceId, withdrawalId } = request.data;
    if (!deviceId || !withdrawalId) {
        throw new functions.https.HttpsError("invalid-argument", "deviceId and withdrawalId are required");
    }
    const withdrawalRef = db.collection("withdrawals").doc(withdrawalId);
    const deviceRef = db.collection("devices").doc(deviceId);
    await db.runTransaction(async (transaction) => {
        const withdrawalDoc = await transaction.get(withdrawalRef);
        if (!withdrawalDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Withdrawal not found");
        }
        const withdrawalData = withdrawalDoc.data();
        // Verify ownership
        if (withdrawalData?.deviceId !== deviceId) {
            throw new functions.https.HttpsError("permission-denied", "You can only cancel your own withdrawals");
        }
        // Only pending withdrawals can be cancelled
        if (withdrawalData?.status !== "pending") {
            throw new functions.https.HttpsError("failed-precondition", "Only pending withdrawals can be cancelled");
        }
        // Refund balance
        transaction.update(deviceRef, {
            balance: admin.firestore.FieldValue.increment(withdrawalData.points),
        });
        // Update withdrawal status
        transaction.update(withdrawalRef, {
            status: "rejected",
            rejectionReason: "Cancelled by user",
            processedAt: admin.firestore.Timestamp.now(),
        });
        // Log refund
        const logRef = db.collection("activity_logs").doc();
        transaction.set(logRef, {
            deviceId,
            type: "admin_adjustment",
            description: "Withdrawal Cancelled - Refund",
            amount: withdrawalData.points,
            timestamp: admin.firestore.Timestamp.now(),
        });
    });
    return {
        success: true,
        message: "Withdrawal cancelled and refunded",
    };
});
// ========== GET WITHDRAWAL CONFIG ==========
exports.getWithdrawalConfig = functions.https.onCall(async () => {
    const settingsRef = db.collection("app_settings").doc("global");
    const settingsDoc = await settingsRef.get();
    const settings = settingsDoc.exists ? settingsDoc.data() : {};
    return {
        success: true,
        config: {
            minWithdrawMMK: settings?.minWithdrawMMK || MIN_WITHDRAW_MMK,
            minWithdrawUSD: settings?.minWithdrawUSD || MIN_WITHDRAW_USD,
            paymentMethods: settings?.paymentMethods || ["KBZ Pay", "Wave Pay"],
            exchangeRate: MMK_TO_USD_RATE,
        },
    };
});
//# sourceMappingURL=withdrawals.js.map