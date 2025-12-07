"use strict";
/**
 * Device Management Functions
 * - Register/Update Device
 * - Get Device Info
 * - Device Status Updates
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
exports.updateDataUsage = exports.updateDeviceStatus = exports.getDeviceInfo = exports.registerDevice = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
// ========== REGISTER DEVICE ==========
exports.registerDevice = functions.https.onCall(async (request) => {
    const { deviceId, deviceModel, appVersion, platform, fcmToken } = request.data;
    if (!deviceId || !deviceModel) {
        throw new functions.https.HttpsError("invalid-argument", "deviceId and deviceModel are required");
    }
    const deviceRef = db.collection("devices").doc(deviceId);
    const deviceDoc = await deviceRef.get();
    const now = admin.firestore.FieldValue.serverTimestamp();
    if (!deviceDoc.exists) {
        // New device - create with initial balance
        const newDevice = {
            deviceModel,
            appVersion,
            platform: platform || "unknown",
            balance: 0,
            status: "online",
            dataUsage: 0,
            country: "Unknown",
            flag: "🏳️",
            ipAddress: "",
            fcmToken: fcmToken || "",
            createdAt: now,
            lastSeen: now,
        };
        await deviceRef.set(newDevice);
        return {
            success: true,
            isNewDevice: true,
            message: "Device registered successfully",
        };
    }
    else {
        // Existing device - update last seen
        const updateData = {
            appVersion,
            lastSeen: now,
            status: "online",
        };
        if (fcmToken) {
            updateData.fcmToken = fcmToken;
        }
        await deviceRef.update(updateData);
        return {
            success: true,
            isNewDevice: false,
            message: "Device updated successfully",
        };
    }
});
// ========== GET DEVICE INFO ==========
exports.getDeviceInfo = functions.https.onCall(async (request) => {
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
    // Check if device is banned
    if (deviceData.status === "banned") {
        return {
            success: false,
            isBanned: true,
            message: "This device has been banned",
        };
    }
    return {
        success: true,
        device: {
            deviceId,
            deviceModel: deviceData.deviceModel,
            balance: deviceData.balance,
            status: deviceData.status,
            dataUsage: deviceData.dataUsage,
        },
    };
});
// ========== UPDATE DEVICE STATUS ==========
exports.updateDeviceStatus = functions.https.onCall(async (request) => {
    const { deviceId, status, ipAddress, country, flag } = request.data;
    if (!deviceId || !status) {
        throw new functions.https.HttpsError("invalid-argument", "deviceId and status are required");
    }
    const deviceRef = db.collection("devices").doc(deviceId);
    const deviceDoc = await deviceRef.get();
    if (!deviceDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Device not found");
    }
    const updateData = {
        status,
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (ipAddress)
        updateData.ipAddress = ipAddress;
    if (country)
        updateData.country = country;
    if (flag)
        updateData.flag = flag;
    await deviceRef.update(updateData);
    return {
        success: true,
        message: "Device status updated",
    };
});
// ========== UPDATE DATA USAGE ==========
exports.updateDataUsage = functions.https.onCall(async (request) => {
    const { deviceId, bytesUsed } = request.data;
    if (!deviceId || bytesUsed === undefined) {
        throw new functions.https.HttpsError("invalid-argument", "deviceId and bytesUsed are required");
    }
    const deviceRef = db.collection("devices").doc(deviceId);
    await deviceRef.update({
        dataUsage: admin.firestore.FieldValue.increment(bytesUsed),
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
        success: true,
        message: "Data usage updated",
    };
});
//# sourceMappingURL=devices.js.map