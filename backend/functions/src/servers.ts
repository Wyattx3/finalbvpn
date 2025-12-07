/**
 * VPN Server Functions
 * - Get Server List
 * - Get Server by ID
 * - Report Server Issue
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// ========== INTERFACES ==========
interface V2RayServer {
  id: string;
  name: string;
  flag: string;
  address: string;
  port: number;
  uuid: string;
  alterId: number;
  security: string;
  network: string;
  path: string;
  tls: boolean;
  country: string;
  status: "online" | "offline" | "maintenance";
  isPremium: boolean;
  load: number;
}

// ========== GET ALL SERVERS ==========
export const getServers = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<{
      includeOffline?: boolean;
      countryFilter?: string;
    }>
  ) => {
    const { includeOffline = false, countryFilter } = request.data || {};

    let query: admin.firestore.Query = db.collection("servers");

    // Filter by status if not including offline
    if (!includeOffline) {
      query = query.where("status", "in", ["online", "maintenance"]);
    }

    // Filter by country if specified
    if (countryFilter) {
      query = query.where("country", "==", countryFilter);
    }

    const snapshot = await query.get();

    const servers = snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        name: data.name,
        flag: data.flag,
        address: data.address,
        port: data.port,
        uuid: data.uuid,
        alterId: data.alterId || 0,
        security: data.security || "auto",
        network: data.network || "ws",
        path: data.path || "/",
        tls: data.tls !== false,
        country: data.country,
        status: data.status,
        isPremium: data.isPremium || false,
        load: data.load || 0,
      } as V2RayServer;
    });

    // Sort by country and load
    servers.sort((a, b) => {
      if (a.country === b.country) {
        return a.load - b.load;
      }
      return a.country.localeCompare(b.country);
    });

    return {
      success: true,
      servers,
      count: servers.length,
    };
  }
);

// ========== GET SERVER BY ID ==========
export const getServerById = functions.https.onCall(
  async (request: functions.https.CallableRequest<{ serverId: string }>) => {
    const { serverId } = request.data;

    if (!serverId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "serverId is required"
      );
    }

    const serverRef = db.collection("servers").doc(serverId);
    const serverDoc = await serverRef.get();

    if (!serverDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Server not found");
    }

    const data = serverDoc.data();

    return {
      success: true,
      server: {
        id: serverDoc.id,
        name: data?.name,
        flag: data?.flag,
        address: data?.address,
        port: data?.port,
        uuid: data?.uuid,
        alterId: data?.alterId || 0,
        security: data?.security || "auto",
        network: data?.network || "ws",
        path: data?.path || "/",
        tls: data?.tls !== false,
        country: data?.country,
        status: data?.status,
        isPremium: data?.isPremium || false,
        load: data?.load || 0,
      },
    };
  }
);

// ========== GET COUNTRIES ==========
export const getServerCountries = functions.https.onCall(async () => {
  const snapshot = await db
    .collection("servers")
    .where("status", "!=", "offline")
    .get();

  const countriesMap = new Map<string, { flag: string; count: number }>();

  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    const country = data.country;
    const flag = data.flag;

    if (countriesMap.has(country)) {
      const existing = countriesMap.get(country)!;
      existing.count++;
    } else {
      countriesMap.set(country, { flag, count: 1 });
    }
  });

  const countries = Array.from(countriesMap.entries()).map(
    ([country, { flag, count }]) => ({
      country,
      flag,
      serverCount: count,
    })
  );

  // Sort by server count (descending)
  countries.sort((a, b) => b.serverCount - a.serverCount);

  return {
    success: true,
    countries,
  };
});

// ========== REPORT SERVER ISSUE ==========
export const reportServerIssue = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<{
      deviceId: string;
      serverId: string;
      issueType: string;
      description?: string;
    }>
  ) => {
    const { deviceId, serverId, issueType, description } = request.data;

    if (!deviceId || !serverId || !issueType) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "deviceId, serverId, and issueType are required"
      );
    }

    const reportRef = db.collection("server_reports").doc();
    await reportRef.set({
      deviceId,
      serverId,
      issueType,
      description: description || "",
      status: "open",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      reportId: reportRef.id,
      message: "Issue reported. Thank you for your feedback!",
    };
  }
);

// ========== GENERATE VMESS LINK ==========
export const generateVmessLink = functions.https.onCall(
  async (request: functions.https.CallableRequest<{ serverId: string }>) => {
    const { serverId } = request.data;

    if (!serverId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "serverId is required"
      );
    }

    const serverRef = db.collection("servers").doc(serverId);
    const serverDoc = await serverRef.get();

    if (!serverDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Server not found");
    }

    const data = serverDoc.data();

    // Generate VMess configuration
    const vmessConfig = {
      v: "2",
      ps: data?.name,
      add: data?.address,
      port: data?.port,
      id: data?.uuid,
      aid: data?.alterId || 0,
      scy: data?.security || "auto",
      net: data?.network || "ws",
      type: "none",
      host: "",
      path: data?.path || "/",
      tls: data?.tls ? "tls" : "",
    };

    const vmessLink = `vmess://${Buffer.from(
      JSON.stringify(vmessConfig)
    ).toString("base64")}`;

    return {
      success: true,
      vmessLink,
      config: vmessConfig,
    };
  }
);

