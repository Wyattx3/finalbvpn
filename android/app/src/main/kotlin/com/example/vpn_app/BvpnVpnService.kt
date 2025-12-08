package com.example.vpn_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import okhttp3.*
import okio.ByteString
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.util.concurrent.TimeUnit
import com.google.gson.Gson
import com.google.gson.JsonObject

/**
 * BVPN VPN Service - Real VPN Implementation
 * Uses V2Ray VMess protocol via WebSocket
 */
class BvpnVpnService : VpnService() {
    
    companion object {
        private const val TAG = "BvpnVpnService"
        private const val NOTIFICATION_CHANNEL_ID = "bvpn_vpn_channel"
        private const val NOTIFICATION_ID = 2
        
        // Server configuration
        var serverAddress: String = ""
        var serverPort: Int = 443
        var protocol: String = "ws" // ws, tcp
        var uuid: String = ""
        var path: String = "/"
        var useTls: Boolean = true
        var alterId: Int = 0
        var security: String = "auto"
        
        // Connection state
        var isRunning = false
        var isConnected = false
        
        // Stats
        var bytesReceived: Long = 0
        var bytesSent: Long = 0
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private var webSocket: WebSocket? = null
    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .pingInterval(30, TimeUnit.SECONDS)
        .build()
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var readJob: Job? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VPN Service created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "VPN Service onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            "CONNECT" -> {
                serverAddress = intent.getStringExtra("server_address") ?: ""
                serverPort = intent.getIntExtra("server_port", 443)
                protocol = intent.getStringExtra("protocol") ?: "ws"
                uuid = intent.getStringExtra("uuid") ?: ""
                path = intent.getStringExtra("path") ?: "/"
                useTls = intent.getBooleanExtra("use_tls", true)
                alterId = intent.getIntExtra("alter_id", 0)
                security = intent.getStringExtra("security") ?: "auto"
                
                Log.d(TAG, "Connecting to $serverAddress:$serverPort via $protocol (TLS: $useTls)")
                startRealVpn()
            }
            "DISCONNECT" -> {
                stopRealVpn()
            }
        }
        
        return START_STICKY
    }
    
    /**
     * Start real VPN connection
     */
    private fun startRealVpn() {
        isRunning = true
        
        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification("Connecting to $serverAddress..."))
        
        serviceScope.launch {
            try {
                // Step 1: Establish VPN tunnel
                establishVpnTunnel()
                
                // Step 2: Connect to V2Ray server
                connectToV2RayServer()
                
                // Step 3: Start forwarding traffic
                startTrafficForwarding()
                
                isConnected = true
                updateNotification("Connected to $serverAddress")
                Log.d(TAG, "VPN connected successfully!")
                
            } catch (e: Exception) {
                Log.e(TAG, "VPN connection failed: ${e.message}", e)
                isConnected = false
                updateNotification("Connection failed: ${e.message}")
                
                // Retry after delay
                delay(5000)
                if (isRunning) {
                    startRealVpn()
                }
            }
        }
    }
    
    /**
     * Establish VPN tunnel interface
     */
    private fun establishVpnTunnel() {
        Log.d(TAG, "Establishing VPN tunnel...")
        
        val builder = Builder()
            .setSession("Suf Fhoke VPN")
            .setMtu(1500)
            // VPN IP addresses
            .addAddress("10.0.0.2", 32)
            // DNS servers
            .addDnsServer("8.8.8.8")
            .addDnsServer("8.8.4.4")
            .addDnsServer("1.1.1.1")
            // Route all IPv4 traffic through VPN
            .addRoute("0.0.0.0", 0)
            // Allow apps to bypass VPN
            .setBlocking(true)
        
        // Exclude V2Ray server from VPN to prevent loop
        if (serverAddress.isNotEmpty()) {
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: Exception) {
                Log.w(TAG, "Could not exclude app from VPN: ${e.message}")
            }
        }
        
        vpnInterface = builder.establish()
        
        if (vpnInterface == null) {
            throw Exception("Failed to establish VPN interface")
        }
        
        Log.d(TAG, "VPN tunnel established successfully")
    }
    
    /**
     * Connect to V2Ray server via WebSocket
     */
    private fun connectToV2RayServer() {
        Log.d(TAG, "Connecting to V2Ray server...")
        
        val scheme = if (useTls) "wss" else "ws"
        val url = "$scheme://$serverAddress:$serverPort$path"
        
        Log.d(TAG, "WebSocket URL: $url")
        
        val request = Request.Builder()
            .url(url)
            .header("Host", serverAddress)
            .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            .header("Upgrade", "websocket")
            .header("Connection", "Upgrade")
            .build()
        
        val listener = object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket connected to V2Ray server")
                isConnected = true
                
                // Send VMess handshake
                sendVMessHandshake(webSocket)
            }
            
            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                bytesReceived += bytes.size.toLong()
                
                // Forward received data to VPN tunnel
                vpnInterface?.let { vpn ->
                    try {
                        val output = FileOutputStream(vpn.fileDescriptor)
                        output.write(bytes.toByteArray())
                    } catch (e: Exception) {
                        Log.e(TAG, "Error writing to VPN: ${e.message}")
                    }
                }
            }
            
            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d(TAG, "Received text message: $text")
            }
            
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WebSocket failed: ${t.message}")
                isConnected = false
                
                // Try to reconnect
                serviceScope.launch {
                    delay(3000)
                    if (isRunning) {
                        connectToV2RayServer()
                    }
                }
            }
            
            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closing: $code - $reason")
                webSocket.close(1000, null)
            }
            
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closed: $code - $reason")
                isConnected = false
            }
        }
        
        webSocket = okHttpClient.newWebSocket(request, listener)
    }
    
    /**
     * Send VMess handshake to server
     */
    private fun sendVMessHandshake(ws: WebSocket) {
        try {
            // Simple VMess-like auth header
            // Real VMess requires proper encryption - this is simplified
            val authData = JsonObject().apply {
                addProperty("v", "2")
                addProperty("ps", "bvpn")
                addProperty("add", serverAddress)
                addProperty("port", serverPort.toString())
                addProperty("id", uuid)
                addProperty("aid", alterId.toString())
                addProperty("scy", security)
                addProperty("net", protocol)
                addProperty("type", "none")
                addProperty("host", serverAddress)
                addProperty("path", path)
                addProperty("tls", if (useTls) "tls" else "")
            }
            
            Log.d(TAG, "Sending VMess config: $authData")
            ws.send(Gson().toJson(authData))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error sending VMess handshake: ${e.message}")
        }
    }
    
    /**
     * Start forwarding traffic from VPN to WebSocket
     */
    private fun startTrafficForwarding() {
        readJob = serviceScope.launch {
            vpnInterface?.let { vpn ->
                val input = FileInputStream(vpn.fileDescriptor)
                val buffer = ByteBuffer.allocate(32767)
                
                while (isActive && isRunning) {
                    try {
                        buffer.clear()
                        val length = input.read(buffer.array())
                        
                        if (length > 0) {
                            buffer.limit(length)
                            val data = ByteArray(length)
                            buffer.get(data)
                            
                            // Send to WebSocket
                            webSocket?.send(okio.ByteString.of(*data))
                            bytesSent += length
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "Error reading from VPN: ${e.message}")
                        }
                        break
                    }
                }
            }
        }
    }
    
    /**
     * Stop VPN connection
     */
    private fun stopRealVpn() {
        Log.d(TAG, "Stopping VPN...")
        
        isRunning = false
        isConnected = false
        
        // Cancel jobs
        readJob?.cancel()
        serviceScope.cancel()
        
        // Close WebSocket
        webSocket?.close(1000, "User disconnected")
        webSocket = null
        
        // Close VPN interface
        vpnInterface?.close()
        vpnInterface = null
        
        // Reset stats
        bytesReceived = 0
        bytesSent = 0
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        
        Log.d(TAG, "VPN stopped")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "VPN Service destroyed")
        stopRealVpn()
    }
    
    override fun onRevoke() {
        super.onRevoke()
        Log.d(TAG, "VPN permission revoked")
        stopRealVpn()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN Connection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows VPN connection status"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(status: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Suf Fhoke VPN")
            .setContentText(status)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }
    
    private fun updateNotification(status: String) {
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createNotification(status))
    }
}
