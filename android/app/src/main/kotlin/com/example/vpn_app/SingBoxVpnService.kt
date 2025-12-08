package com.example.vpn_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.*

class SingBoxVpnService : VpnService() {
    
    companion object {
        private const val TAG = "SingBoxVpnService"
        private const val NOTIFICATION_CHANNEL_ID = "vpn_service_channel"
        private const val NOTIFICATION_ID = 2
        private const val SOCKS_PORT = 10808
        private const val HTTP_PORT = 10809
        
        @Volatile
        var isRunning = false
            private set
            
        @Volatile
        var lastError: String? = null
            private set
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private var singBoxProcess: Process? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Server config
    private var serverAddress: String = ""
    private var serverPort: Int = 443
    private var uuid: String = ""
    private var protocol: String = "ws"
    private var path: String = "/"
    private var useTls: Boolean = true
    private var alterId: Int = 0
    private var security: String = "auto"
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "SingBox VPN Service created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "SingBox VPN Service onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            "CONNECT" -> {
                serverAddress = intent.getStringExtra("server_address") ?: ""
                serverPort = intent.getIntExtra("server_port", 443)
                uuid = intent.getStringExtra("uuid") ?: ""
                protocol = intent.getStringExtra("protocol") ?: "ws"
                path = intent.getStringExtra("path") ?: "/"
                useTls = intent.getBooleanExtra("use_tls", true)
                alterId = intent.getIntExtra("alter_id", 0)
                security = intent.getStringExtra("security") ?: "auto"
                
                Log.d(TAG, "Connecting to: $serverAddress:$serverPort via $protocol (TLS: $useTls)")
                startVpn()
            }
            "DISCONNECT" -> {
                stopVpn()
            }
        }
        
        return START_STICKY
    }
    
    private fun startVpn() {
        if (isRunning) {
            Log.d(TAG, "VPN already running")
            return
        }
        
        isRunning = true
        lastError = null
        startForeground(NOTIFICATION_ID, createNotification("Connecting..."))
        
        scope.launch {
            try {
                // Step 1: Copy sing-box binary
                val binaryPath = copySingBoxBinary()
                if (binaryPath == null) {
                    lastError = "Failed to copy sing-box binary"
                    stopVpn()
                    return@launch
                }
                Log.d(TAG, "Binary copied to: $binaryPath")
                
                // Step 2: Create config file
                val configPath = createConfigFile()
                Log.d(TAG, "Config created at: $configPath")
                
                // Step 3: Establish VPN interface
                establishVpnInterface()
                if (vpnInterface == null) {
                    lastError = "Failed to establish VPN interface"
                    stopVpn()
                    return@launch
                }
                Log.d(TAG, "VPN interface established")
                
                // Step 4: Start sing-box process
                startSingBoxProcess(binaryPath, configPath)
                
                // Wait for sing-box to start
                delay(2000)
                
                if (singBoxProcess?.isAlive == true) {
                    Log.d(TAG, "VPN connected successfully!")
                    updateNotification("Connected to $serverAddress")
                } else {
                    lastError = "sing-box process failed to start"
                    stopVpn()
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "VPN error: ${e.message}", e)
                lastError = e.message
                stopVpn()
            }
        }
    }
    
    private fun copySingBoxBinary(): String? {
        try {
            val abi = Build.SUPPORTED_ABIS[0]
            Log.d(TAG, "Device ABI: $abi")
            
            // Use native library from jniLibs (automatically extracted to nativeLibraryDir)
            val nativeLibDir = applicationInfo.nativeLibraryDir
            val binaryPath = "$nativeLibDir/libsingbox.so"
            
            val binaryFile = File(binaryPath)
            if (binaryFile.exists()) {
                Log.d(TAG, "Using native library at: $binaryPath")
                // Make sure it's executable
                binaryFile.setExecutable(true, false)
                return binaryPath
            }
            
            Log.e(TAG, "Native library not found at: $binaryPath")
            return null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get binary path: ${e.message}", e)
            return null
        }
    }
    
    private fun createConfigFile(): String {
        val configFile = File(filesDir, "config.json")
        
        val tlsConfig = if (useTls) {
            """"tls": {
                "enabled": true,
                "server_name": "$serverAddress",
                "insecure": true
            },"""
        } else {
            ""
        }
        
        val transportConfig = when (protocol) {
            "ws" -> {
                """"transport": {
                    "type": "ws",
                    "path": "$path",
                    "headers": {
                        "Host": "$serverAddress"
                    }
                }"""
            }
            "tcp" -> {
                ""
            }
            "grpc" -> {
                """"transport": {
                    "type": "grpc",
                    "service_name": "${path.removePrefix("/")}"
                }"""
            }
            else -> ""
        }
        
        // sing-box 1.12+ config format
        val config = """
{
    "log": {
        "level": "info",
        "output": "${File(filesDir, "sing-box.log").absolutePath}"
    },
    "dns": {
        "servers": [
            {
                "tag": "google-doh",
                "address": "8.8.8.8",
                "address_resolver": "local-dns"
            },
            {
                "tag": "local-dns",
                "address": "local"
            }
        ],
        "rules": [
            {
                "outbound": "any",
                "server": "local-dns"
            }
        ],
        "strategy": "ipv4_only"
    },
    "inbounds": [
        {
            "type": "tun",
            "tag": "tun-in",
            "address": "172.19.0.1/30",
            "mtu": 1500,
            "auto_route": true,
            "strict_route": true,
            "stack": "system",
            "sniff": true,
            "sniff_override_destination": true
        }
    ],
    "outbounds": [
        {
            "type": "vmess",
            "tag": "proxy",
            "server": "$serverAddress",
            "server_port": $serverPort,
            "uuid": "$uuid",
            "security": "$security",
            "alter_id": $alterId,
            $tlsConfig
            $transportConfig
        }
    ],
    "route": {
        "rules": [
            {
                "action": "hijack-dns",
                "protocol": "dns"
            },
            {
                "action": "route",
                "ip_is_private": true,
                "outbound": "proxy"
            }
        ],
        "final": "proxy",
        "auto_detect_interface": true
    }
}
""".trimIndent()
        
        configFile.writeText(config)
        Log.d(TAG, "Config content:\n$config")
        return configFile.absolutePath
    }
    
    private fun establishVpnInterface(): Boolean {
        try {
            val builder = Builder()
                .setSession("Suf Fhoke VPN")
                .setMtu(1500)
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")
            
            // Exclude this app from VPN
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: Exception) {
                Log.w(TAG, "Could not exclude app: ${e.message}")
            }
            
            vpnInterface = builder.establish()
            return vpnInterface != null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN interface: ${e.message}", e)
            return false
        }
    }
    
    private fun startSingBoxProcess(binaryPath: String, configPath: String) {
        try {
            val fd = vpnInterface?.fd ?: return
            
            val processBuilder = ProcessBuilder(
                binaryPath,
                "run",
                "-c", configPath
            )
            
            // Set environment variables
            processBuilder.environment()["TUN_FD"] = fd.toString()
            // Enable deprecated features for backward compatibility
            processBuilder.environment()["ENABLE_DEPRECATED_SPECIAL_OUTBOUNDS"] = "true"
            processBuilder.environment()["ENABLE_DEPRECATED_DNS_SERVERS"] = "true"
            processBuilder.redirectErrorStream(true)
            
            singBoxProcess = processBuilder.start()
            
            // Log output
            scope.launch {
                try {
                    singBoxProcess?.inputStream?.bufferedReader()?.use { reader ->
                        var line: String?
                        while (reader.readLine().also { line = it } != null && isRunning) {
                            Log.d(TAG, "sing-box: $line")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading sing-box output: ${e.message}")
                }
            }
            
            Log.d(TAG, "sing-box process started with PID: ${singBoxProcess?.toString()}")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start sing-box: ${e.message}", e)
            throw e
        }
    }
    
    private fun stopVpn() {
        Log.d(TAG, "Stopping VPN...")
        isRunning = false
        
        scope.cancel()
        
        // Stop sing-box process
        try {
            singBoxProcess?.destroy()
            singBoxProcess?.waitFor()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping sing-box: ${e.message}")
        }
        singBoxProcess = null
        
        // Close VPN interface
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface: ${e.message}")
        }
        vpnInterface = null
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        
        Log.d(TAG, "VPN stopped")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
            }
            
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Suf Fhoke VPN")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(text: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, createNotification(text))
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopVpn()
    }
    
    override fun onRevoke() {
        super.onRevoke()
        stopVpn()
    }
}

