"use strict";
/**
 * Admin Functions
 * - Process Withdrawal (Approve/Reject)
 * - Ban/Unban Device
 * - Adjust Balance
 * - CRUD Servers
 * - Update SDUI Configs
 * - Dashboard Stats
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
exports.getAllWithdrawals = exports.getAnalyticsSummary = exports.getCountryDistribution = exports.getAnalyticsData = exports.seedInitialData = exports.getAllDevices = exports.getDashboardStats = exports.updateSduiConfig = exports.deleteServer = exports.updateServer = exports.addServer = exports.adjustBalance = exports.toggleDeviceBan = exports.processWithdrawal = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
// ========== HELPER: CHECK ADMIN ==========
async function checkAdmin(adminId) {
    const adminDoc = await db.collection("admins").doc(adminId).get();
    return adminDoc.exists;
}
// ========== PROCESS WITHDRAWAL ==========
exports.processWithdrawal = functions.https.onCall(async (request) => {
    const { adminId, withdrawalId, action, rejectionReason } = request.data;
    if (!adminId || !withdrawalId || !action) {
        throw new functions.https.HttpsError("invalid-argument", "adminId, withdrawalId, and action are required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    const withdrawalRef = db.collection("withdrawals").doc(withdrawalId);
    await db.runTransaction(async (transaction) => {
        const withdrawalDoc = await transaction.get(withdrawalRef);
        if (!withdrawalDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Withdrawal not found");
        }
        const withdrawalData = withdrawalDoc.data();
        if (withdrawalData?.status !== "pending") {
            throw new functions.https.HttpsError("failed-precondition", "Withdrawal already processed");
        }
        // Update withdrawal status
        const updateData = {
            status: action,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            processedBy: adminId,
        };
        if (action === "rejected" && rejectionReason) {
            updateData.rejectionReason = rejectionReason;
        }
        transaction.update(withdrawalRef, updateData);
        // If rejected, refund balance
        if (action === "rejected") {
            const deviceRef = db.collection("devices").doc(withdrawalData.deviceId);
            transaction.update(deviceRef, {
                balance: admin.firestore.FieldValue.increment(withdrawalData.points),
            });
            // Log refund
            const logRef = db.collection("activity_logs").doc();
            transaction.set(logRef, {
                deviceId: withdrawalData.deviceId,
                type: "admin_adjustment",
                description: `Withdrawal Rejected - Refund (${rejectionReason || "No reason"})`,
                amount: withdrawalData.points,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    });
    return {
        success: true,
        message: `Withdrawal ${action}`,
    };
});
// ========== BAN/UNBAN DEVICE ==========
exports.toggleDeviceBan = functions.https.onCall(async (request) => {
    const { adminId, deviceId, ban, reason } = request.data;
    if (!adminId || !deviceId || ban === undefined) {
        throw new functions.https.HttpsError("invalid-argument", "adminId, deviceId, and ban are required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    const deviceRef = db.collection("devices").doc(deviceId);
    const deviceDoc = await deviceRef.get();
    if (!deviceDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Device not found");
    }
    await deviceRef.update({
        status: ban ? "banned" : "offline",
        banReason: ban ? reason || "Banned by admin" : null,
        bannedAt: ban
            ? admin.firestore.FieldValue.serverTimestamp()
            : null,
        bannedBy: ban ? adminId : null,
    });
    return {
        success: true,
        message: ban ? "Device banned" : "Device unbanned",
    };
});
// ========== ADJUST BALANCE ==========
exports.adjustBalance = functions.https.onCall(async (request) => {
    const { adminId, deviceId, amount, reason } = request.data;
    if (!adminId || !deviceId || amount === undefined || !reason) {
        throw new functions.https.HttpsError("invalid-argument", "adminId, deviceId, amount, and reason are required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    const deviceRef = db.collection("devices").doc(deviceId);
    await db.runTransaction(async (transaction) => {
        const deviceDoc = await transaction.get(deviceRef);
        if (!deviceDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Device not found");
        }
        const currentBalance = deviceDoc.data()?.balance || 0;
        const newBalance = currentBalance + amount;
        if (newBalance < 0) {
            throw new functions.https.HttpsError("failed-precondition", "Balance cannot go negative");
        }
        transaction.update(deviceRef, {
            balance: newBalance,
        });
        // Log activity
        const logRef = db.collection("activity_logs").doc();
        transaction.set(logRef, {
            deviceId,
            type: "admin_adjustment",
            description: reason,
            amount,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            adjustedBy: adminId,
        });
    });
    return {
        success: true,
        message: `Balance adjusted by ${amount > 0 ? "+" : ""}${amount}`,
    };
});
// ========== CRUD SERVERS ==========
exports.addServer = functions.https.onCall(async (request) => {
    const { adminId, server } = request.data;
    if (!adminId || !server) {
        throw new functions.https.HttpsError("invalid-argument", "adminId and server data are required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    const serverRef = db.collection("servers").doc();
    await serverRef.set({
        ...server,
        alterId: server.alterId || 0,
        security: server.security || "auto",
        network: server.network || "ws",
        path: server.path || "/",
        tls: server.tls !== false,
        isPremium: server.isPremium || false,
        status: "online",
        load: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: adminId,
    });
    return {
        success: true,
        serverId: serverRef.id,
        message: "Server added successfully",
    };
});
exports.updateServer = functions.https.onCall(async (request) => {
    const { adminId, serverId, updates } = request.data;
    if (!adminId || !serverId || !updates) {
        throw new functions.https.HttpsError("invalid-argument", "adminId, serverId, and updates are required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    const serverRef = db.collection("servers").doc(serverId);
    const serverDoc = await serverRef.get();
    if (!serverDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Server not found");
    }
    await serverRef.update({
        ...updates,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: adminId,
    });
    return {
        success: true,
        message: "Server updated successfully",
    };
});
exports.deleteServer = functions.https.onCall(async (request) => {
    const { adminId, serverId } = request.data;
    if (!adminId || !serverId) {
        throw new functions.https.HttpsError("invalid-argument", "adminId and serverId are required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    await db.collection("servers").doc(serverId).delete();
    return {
        success: true,
        message: "Server deleted successfully",
    };
});
// ========== UPDATE SDUI CONFIG ==========
exports.updateSduiConfig = functions.https.onCall(async (request) => {
    const { adminId, screenId, config } = request.data;
    if (!adminId || !screenId || !config) {
        throw new functions.https.HttpsError("invalid-argument", "adminId, screenId, and config are required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    await db.collection("sdui_configs").doc(screenId).set({
        screen_id: screenId,
        config,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: adminId,
    }, { merge: true });
    return {
        success: true,
        message: "Config updated successfully",
    };
});
// ========== DASHBOARD STATS ==========
exports.getDashboardStats = functions.https.onCall(async (request) => {
    const { adminId } = request.data;
    if (!adminId) {
        throw new functions.https.HttpsError("invalid-argument", "adminId is required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    // Get counts
    const [devicesSnapshot, serversSnapshot, pendingWithdrawalsSnapshot] = await Promise.all([
        db.collection("devices").count().get(),
        db.collection("servers").where("status", "==", "online").count().get(),
        db
            .collection("withdrawals")
            .where("status", "==", "pending")
            .count()
            .get(),
    ]);
    // Get total pending withdrawal amount
    const pendingWithdrawals = await db
        .collection("withdrawals")
        .where("status", "==", "pending")
        .get();
    let totalPendingAmount = 0;
    pendingWithdrawals.docs.forEach((doc) => {
        totalPendingAmount += doc.data().points || 0;
    });
    return {
        success: true,
        stats: {
            totalDevices: devicesSnapshot.data().count,
            activeServers: serversSnapshot.data().count,
            pendingWithdrawals: pendingWithdrawalsSnapshot.data().count,
            totalPendingAmount,
        },
    };
});
// ========== GET ALL DEVICES (Admin) ==========
exports.getAllDevices = functions.https.onCall(async (request) => {
    const { adminId, limit = 100, status } = request.data;
    if (!adminId) {
        throw new functions.https.HttpsError("invalid-argument", "adminId is required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    let query = db
        .collection("devices")
        .orderBy("lastSeen", "desc")
        .limit(limit);
    if (status) {
        query = db
            .collection("devices")
            .where("status", "==", status)
            .orderBy("lastSeen", "desc")
            .limit(limit);
    }
    const snapshot = await query.get();
    const devices = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
        lastSeen: doc.data().lastSeen?.toDate?.()?.toISOString() || null,
    }));
    return {
        success: true,
        devices,
        count: devices.length,
    };
});
// ========== SEED INITIAL DATA ==========
exports.seedInitialData = functions.https.onCall(async (request) => {
    const { adminKey } = request.data || {};
    // Simple security check (you should change this key)
    if (adminKey !== "bvpn-seed-2024") {
        throw new functions.https.HttpsError("permission-denied", "Invalid admin key");
    }
    const batch = db.batch();
    // 1. App Settings
    const appSettingsRef = db.collection("app_settings").doc("global");
    batch.set(appSettingsRef, {
        minAppVersion: "1.0.0",
        latestVersion: "1.0.0",
        forceUpdate: false,
        maintenanceMode: false,
        maintenanceMessage: "",
        rewardPerAd: 30,
        maxAdsPerDay: 100,
        cooldownAfterAds: 10,
        cooldownMinutes: 10,
        timeBonusSeconds: 7200,
        minWithdrawMMK: 20000,
        minWithdrawUSD: 20.0,
        paymentMethods: ["KBZ Pay", "Wave Pay"],
        supportEmail: "support@bvpn.app",
        supportTelegram: "@bvpn_support",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // 2. Sample Servers
    const servers = [
        {
            name: "Singapore SG1",
            flag: "🇸🇬",
            address: "sg1.example.com",
            port: 443,
            uuid: "a1b2c3d4-e5f6-7890-1234-567890abcdef",
            alterId: 0,
            security: "auto",
            network: "ws",
            path: "/vpn",
            tls: true,
            country: "Singapore",
            status: "online",
            isPremium: false,
            load: 25,
        },
        {
            name: "Japan JP1",
            flag: "🇯🇵",
            address: "jp1.example.com",
            port: 443,
            uuid: "b2c3d4e5-f6a7-8901-2345-678901bcdef1",
            alterId: 0,
            security: "auto",
            network: "ws",
            path: "/api",
            tls: true,
            country: "Japan",
            status: "online",
            isPremium: true,
            load: 12,
        },
        {
            name: "United States US1",
            flag: "🇺🇸",
            address: "us1.example.com",
            port: 443,
            uuid: "c3d4e5f6-a7b8-9012-3456-789012cdef12",
            alterId: 0,
            security: "auto",
            network: "ws",
            path: "/stream",
            tls: true,
            country: "United States",
            status: "online",
            isPremium: false,
            load: 35,
        },
    ];
    for (const server of servers) {
        const serverRef = db.collection("servers").doc();
        batch.set(serverRef, {
            ...server,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    // 3. SDUI Configs
    const sduiConfigs = {
        home: {
            screen_id: "home",
            config: {
                type: "dashboard",
                app_bar: {
                    title_disconnected: "Not Connected",
                    title_connecting: "Connecting...",
                    title_connected: "Connected",
                },
                timer_section: { show_timer: true },
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
                title: "Welcome!",
                message: "Welcome to BVPN App",
                is_dismissible: true,
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
    for (const [screenId, config] of Object.entries(sduiConfigs)) {
        const ref = db.collection("sdui_configs").doc(screenId);
        batch.set(ref, {
            ...config,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    // 4. Admin User
    const adminRef = db.collection("admins").doc("admin-001");
    batch.set(adminRef, {
        email: "admin@bvpn.app",
        name: "Admin",
        role: "super_admin",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return {
        success: true,
        message: "Initial data seeded successfully!",
        seeded: {
            appSettings: 1,
            servers: servers.length,
            sduiConfigs: Object.keys(sduiConfigs).length,
            admins: 1,
        },
    };
});
// ========== ANALYTICS: GET CHART DATA ==========
exports.getAnalyticsData = functions.https.onCall(async (request) => {
    const { period = "month", days = 30 } = request.data || {};
    const now = new Date();
    const results = [];
    if (period === "day") {
        // Last N days
        for (let i = days - 1; i >= 0; i--) {
            const date = new Date(now);
            date.setDate(date.getDate() - i);
            const dateStr = date.toISOString().split("T")[0];
            const dayStart = new Date(dateStr + "T00:00:00Z");
            const dayEnd = new Date(dateStr + "T23:59:59Z");
            // Count devices created on this day
            const usersSnapshot = await db
                .collection("devices")
                .where("createdAt", ">=", dayStart)
                .where("createdAt", "<=", dayEnd)
                .count()
                .get();
            // Sum withdrawals on this day
            const withdrawalsSnapshot = await db
                .collection("withdrawals")
                .where("createdAt", ">=", dayStart)
                .where("createdAt", "<=", dayEnd)
                .get();
            let withdrawalSum = 0;
            withdrawalsSnapshot.docs.forEach((doc) => {
                withdrawalSum += doc.data().points || 0;
            });
            // Sum rewards on this day
            const rewardsSnapshot = await db
                .collection("activity_logs")
                .where("type", "==", "ad_reward")
                .where("timestamp", ">=", dayStart)
                .where("timestamp", "<=", dayEnd)
                .get();
            let rewardsSum = 0;
            rewardsSnapshot.docs.forEach((doc) => {
                rewardsSum += doc.data().amount || 0;
            });
            results.push({
                name: `Day ${days - i}`,
                users: usersSnapshot.data().count,
                withdrawals: withdrawalSum,
                rewards: rewardsSum,
            });
        }
    }
    else if (period === "month") {
        // Last 12 months
        const months = [
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        ];
        for (let i = 11; i >= 0; i--) {
            const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
            const monthStart = new Date(date.getFullYear(), date.getMonth(), 1);
            const monthEnd = new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59);
            const usersSnapshot = await db
                .collection("devices")
                .where("createdAt", ">=", monthStart)
                .where("createdAt", "<=", monthEnd)
                .count()
                .get();
            const withdrawalsSnapshot = await db
                .collection("withdrawals")
                .where("createdAt", ">=", monthStart)
                .where("createdAt", "<=", monthEnd)
                .get();
            let withdrawalSum = 0;
            withdrawalsSnapshot.docs.forEach((doc) => {
                withdrawalSum += doc.data().points || 0;
            });
            const rewardsSnapshot = await db
                .collection("activity_logs")
                .where("type", "==", "ad_reward")
                .where("timestamp", ">=", monthStart)
                .where("timestamp", "<=", monthEnd)
                .get();
            let rewardsSum = 0;
            rewardsSnapshot.docs.forEach((doc) => {
                rewardsSum += doc.data().amount || 0;
            });
            results.push({
                name: months[date.getMonth()],
                users: usersSnapshot.data().count,
                withdrawals: withdrawalSum,
                rewards: rewardsSum,
            });
        }
    }
    else {
        // Last 4 years
        for (let i = 3; i >= 0; i--) {
            const year = now.getFullYear() - i;
            const yearStart = new Date(year, 0, 1);
            const yearEnd = new Date(year, 11, 31, 23, 59, 59);
            const usersSnapshot = await db
                .collection("devices")
                .where("createdAt", ">=", yearStart)
                .where("createdAt", "<=", yearEnd)
                .count()
                .get();
            const withdrawalsSnapshot = await db
                .collection("withdrawals")
                .where("createdAt", ">=", yearStart)
                .where("createdAt", "<=", yearEnd)
                .get();
            let withdrawalSum = 0;
            withdrawalsSnapshot.docs.forEach((doc) => {
                withdrawalSum += doc.data().points || 0;
            });
            const rewardsSnapshot = await db
                .collection("activity_logs")
                .where("type", "==", "ad_reward")
                .where("timestamp", ">=", yearStart)
                .where("timestamp", "<=", yearEnd)
                .get();
            let rewardsSum = 0;
            rewardsSnapshot.docs.forEach((doc) => {
                rewardsSum += doc.data().amount || 0;
            });
            results.push({
                name: year.toString(),
                users: usersSnapshot.data().count,
                withdrawals: withdrawalSum,
                rewards: rewardsSum,
            });
        }
    }
    return {
        success: true,
        period,
        data: results,
    };
});
// ========== ANALYTICS: GET COUNTRY DISTRIBUTION ==========
exports.getCountryDistribution = functions.https.onCall(async () => {
    const snapshot = await db.collection("devices").get();
    const countryMap = {};
    snapshot.docs.forEach((doc) => {
        const country = doc.data().country || "Unknown";
        countryMap[country] = (countryMap[country] || 0) + 1;
    });
    // Sort by count and get top 5
    const sorted = Object.entries(countryMap)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5);
    const data = sorted.map(([name, value]) => ({ name, value }));
    // Add "Others" if there are more countries
    const topCount = data.reduce((sum, item) => sum + item.value, 0);
    const totalCount = snapshot.size;
    if (totalCount > topCount) {
        data.push({ name: "Others", value: totalCount - topCount });
    }
    return {
        success: true,
        data,
        total: totalCount,
    };
});
// ========== ANALYTICS: GET SUMMARY STATS ==========
exports.getAnalyticsSummary = functions.https.onCall(async () => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0);
    // Total Users
    const totalUsers = await db.collection("devices").count().get();
    // New users today
    const newUsersToday = await db
        .collection("devices")
        .where("createdAt", ">=", today)
        .count()
        .get();
    // New users yesterday
    const newUsersYesterday = await db
        .collection("devices")
        .where("createdAt", ">=", yesterday)
        .where("createdAt", "<", today)
        .count()
        .get();
    // Active servers
    const activeServers = await db
        .collection("servers")
        .where("status", "==", "online")
        .count()
        .get();
    // Total withdrawals this month
    const withdrawalsThisMonth = await db
        .collection("withdrawals")
        .where("createdAt", ">=", thisMonth)
        .get();
    let withdrawalSumThisMonth = 0;
    withdrawalsThisMonth.docs.forEach((doc) => {
        withdrawalSumThisMonth += doc.data().points || 0;
    });
    // Total withdrawals last month
    const withdrawalsLastMonth = await db
        .collection("withdrawals")
        .where("createdAt", ">=", lastMonth)
        .where("createdAt", "<=", lastMonthEnd)
        .get();
    let withdrawalSumLastMonth = 0;
    withdrawalsLastMonth.docs.forEach((doc) => {
        withdrawalSumLastMonth += doc.data().points || 0;
    });
    // Total rewards earned this month
    const rewardsThisMonth = await db
        .collection("activity_logs")
        .where("type", "==", "ad_reward")
        .where("timestamp", ">=", thisMonth)
        .get();
    let rewardSumThisMonth = 0;
    rewardsThisMonth.docs.forEach((doc) => {
        rewardSumThisMonth += doc.data().amount || 0;
    });
    // Pending withdrawals
    const pendingWithdrawals = await db
        .collection("withdrawals")
        .where("status", "==", "pending")
        .count()
        .get();
    // Calculate changes
    const userChange = newUsersYesterday.data().count > 0
        ? Math.round(((newUsersToday.data().count - newUsersYesterday.data().count) /
            newUsersYesterday.data().count) *
            100)
        : newUsersToday.data().count > 0
            ? 100
            : 0;
    const withdrawalChange = withdrawalSumLastMonth > 0
        ? Math.round(((withdrawalSumThisMonth - withdrawalSumLastMonth) /
            withdrawalSumLastMonth) *
            100)
        : withdrawalSumThisMonth > 0
            ? 100
            : 0;
    return {
        success: true,
        stats: {
            totalUsers: totalUsers.data().count,
            newUsersToday: newUsersToday.data().count,
            userChange,
            activeServers: activeServers.data().count,
            withdrawalsThisMonth: withdrawalSumThisMonth,
            withdrawalChange,
            rewardsThisMonth: rewardSumThisMonth,
            pendingWithdrawals: pendingWithdrawals.data().count,
        },
    };
});
// ========== GET ALL WITHDRAWALS (Admin) ==========
exports.getAllWithdrawals = functions.https.onCall(async (request) => {
    const { adminId, limit = 100, status } = request.data;
    if (!adminId) {
        throw new functions.https.HttpsError("invalid-argument", "adminId is required");
    }
    // Verify admin
    const isAdmin = await checkAdmin(adminId);
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    let query = db
        .collection("withdrawals")
        .orderBy("createdAt", "desc")
        .limit(limit);
    if (status) {
        query = db
            .collection("withdrawals")
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
//# sourceMappingURL=admin.js.map