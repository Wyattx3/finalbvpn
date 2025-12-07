"use strict";
/**
 * VPN Server Functions
 * - Get Server List
 * - Get Server by ID
 * - Report Server Issue
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
exports.generateVmessLink = exports.reportServerIssue = exports.getServerCountries = exports.getServerById = exports.getServers = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
// ========== GET ALL SERVERS ==========
exports.getServers = functions.https.onCall(async (request) => {
    const { includeOffline = false, countryFilter } = request.data || {};
    let query = db.collection("servers");
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
        };
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
});
// ========== GET SERVER BY ID ==========
exports.getServerById = functions.https.onCall(async (request) => {
    const { serverId } = request.data;
    if (!serverId) {
        throw new functions.https.HttpsError("invalid-argument", "serverId is required");
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
});
// ========== GET COUNTRIES ==========
exports.getServerCountries = functions.https.onCall(async () => {
    const snapshot = await db
        .collection("servers")
        .where("status", "!=", "offline")
        .get();
    const countriesMap = new Map();
    snapshot.docs.forEach((doc) => {
        const data = doc.data();
        const country = data.country;
        const flag = data.flag;
        if (countriesMap.has(country)) {
            const existing = countriesMap.get(country);
            existing.count++;
        }
        else {
            countriesMap.set(country, { flag, count: 1 });
        }
    });
    const countries = Array.from(countriesMap.entries()).map(([country, { flag, count }]) => ({
        country,
        flag,
        serverCount: count,
    }));
    // Sort by server count (descending)
    countries.sort((a, b) => b.serverCount - a.serverCount);
    return {
        success: true,
        countries,
    };
});
// ========== REPORT SERVER ISSUE ==========
exports.reportServerIssue = functions.https.onCall(async (request) => {
    const { deviceId, serverId, issueType, description } = request.data;
    if (!deviceId || !serverId || !issueType) {
        throw new functions.https.HttpsError("invalid-argument", "deviceId, serverId, and issueType are required");
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
});
// ========== GENERATE VMESS LINK ==========
exports.generateVmessLink = functions.https.onCall(async (request) => {
    const { serverId } = request.data;
    if (!serverId) {
        throw new functions.https.HttpsError("invalid-argument", "serverId is required");
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
    const vmessLink = `vmess://${Buffer.from(JSON.stringify(vmessConfig)).toString("base64")}`;
    return {
        success: true,
        vmessLink,
        config: vmessConfig,
    };
});
//# sourceMappingURL=servers.js.map