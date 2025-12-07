/**
 * Device Management Functions
 * - Register/Update Device
 * - Get Device Info
 * - Device Status Updates
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// ========== INTERFACES ==========
interface DeviceData {
  deviceId: string;
  deviceModel: string;
  appVersion: string;
  platform?: string;
  fcmToken?: string;
}

interface DeviceDocument {
  deviceModel: string;
  appVersion: string;
  platform: string;
  balance: number;
  status: "online" | "offline" | "banned";
  dataUsage: number;
  country: string;
  flag: string;
  ipAddress: string;
  fcmToken?: string;
  createdAt: admin.firestore.Timestamp;
  lastSeen: admin.firestore.Timestamp;
}

// ========== REGISTER DEVICE ==========
export const registerDevice = functions.https.onCall(
  async (request: functions.https.CallableRequest<DeviceData>) => {
    const { deviceId, deviceModel, appVersion, platform, fcmToken } = request.data;

    if (!deviceId || !deviceModel) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "deviceId and deviceModel are required"
      );
    }

    const deviceRef = db.collection("devices").doc(deviceId);
    const deviceDoc = await deviceRef.get();

    const now = admin.firestore.FieldValue.serverTimestamp();

    if (!deviceDoc.exists) {
      // New device - create with initial balance
      const newDevice: Partial<DeviceDocument> = {
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
        createdAt: now as admin.firestore.Timestamp,
        lastSeen: now as admin.firestore.Timestamp,
      };

      await deviceRef.set(newDevice);

      return {
        success: true,
        isNewDevice: true,
        message: "Device registered successfully",
      };
    } else {
      // Existing device - update last seen
      const updateData: Partial<DeviceDocument> = {
        appVersion,
        lastSeen: now as admin.firestore.Timestamp,
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
  }
);

// ========== GET DEVICE INFO ==========
export const getDeviceInfo = functions.https.onCall(
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

    const deviceData = deviceDoc.data() as DeviceDocument;

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
  }
);

// ========== UPDATE DEVICE STATUS ==========
export const updateDeviceStatus = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<{
      deviceId: string;
      status: "online" | "offline";
      ipAddress?: string;
      country?: string;
      flag?: string;
    }>
  ) => {
    const { deviceId, status, ipAddress, country, flag } = request.data;

    if (!deviceId || !status) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "deviceId and status are required"
      );
    }

    const deviceRef = db.collection("devices").doc(deviceId);
    const deviceDoc = await deviceRef.get();

    if (!deviceDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Device not found");
    }

    const updateData: Record<string, unknown> = {
      status,
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (ipAddress) updateData.ipAddress = ipAddress;
    if (country) updateData.country = country;
    if (flag) updateData.flag = flag;

    await deviceRef.update(updateData);

    return {
      success: true,
      message: "Device status updated",
    };
  }
);

// ========== UPDATE DATA USAGE ==========
export const updateDataUsage = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<{
      deviceId: string;
      bytesUsed: number;
    }>
  ) => {
    const { deviceId, bytesUsed } = request.data;

    if (!deviceId || bytesUsed === undefined) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "deviceId and bytesUsed are required"
      );
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
  }
);

