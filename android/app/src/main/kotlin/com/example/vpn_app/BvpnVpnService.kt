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
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.DatagramChannel

/**
 * BVPN VPN Service
 * Handles the actual VPN tunnel connection using V2Ray protocol
 */
class BvpnVpnService : VpnService() {
    
    companion object {
        private const val TAG = "BvpnVpnService"
        private const val NOTIFICATION_CHANNEL_ID = "bvpn_vpn_channel"
        private const val NOTIFICATION_ID = 2
        
        // Server configuration
        var serverAddress: String = ""
        var serverPort: Int = 443
        var protocol: String = "ws" // ws, tcp, quic
        var uuid: String = ""
        
        // Connection state
        var isRunning = false
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private var isConnected = false
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VPN Service created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "VPN Service onStartCommand")
        
        when (intent?.action) {
            "CONNECT" -> {
                serverAddress = intent.getStringExtra("server_address") ?: ""
                serverPort = intent.getIntExtra("server_port", 443)
                protocol = intent.getStringExtra("protocol") ?: "ws"
                uuid = intent.getStringExtra("uuid") ?: ""
                
                Log.d(TAG, "Connecting to $serverAddress:$serverPort via $protocol")
                startVpn()
            }
            "DISCONNECT" -> {
                stopVpn()
            }
        }
        
        return START_STICKY
    }
    
    private fun startVpn() {
        // Start foreground service with notification
        startForeground(NOTIFICATION_ID, createNotification("Connecting..."))
        
        try {
            // Configure and establish VPN interface
            val builder = Builder()
                .setSession("BVPN")
                .addAddress("10.0.0.2", 24) // Virtual IP for VPN
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")
                .addRoute("0.0.0.0", 0) // Route all traffic through VPN
                .setMtu(1500)
            
            // Allow apps to bypass VPN if needed
            // builder.addDisallowedApplication("com.example.someapp")
            
            vpnInterface = builder.establish()
            
            if (vpnInterface != null) {
                isConnected = true
                isRunning = true
                Log.d(TAG, "VPN interface established")
                
                // Update notification
                val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.notify(NOTIFICATION_ID, createNotification("Connected to $serverAddress"))
                
                // Start packet forwarding in background thread
                Thread {
                    runVpnLoop()
                }.start()
            } else {
                Log.e(TAG, "Failed to establish VPN interface")
                stopSelf()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting VPN: ${e.message}")
            e.printStackTrace()
            stopSelf()
        }
    }
    
    private fun runVpnLoop() {
        // This is a simplified VPN loop
        // In production, you would integrate V2Ray core library here
        // to handle actual VMess/VLESS protocol
        
        val vpnInput = FileInputStream(vpnInterface?.fileDescriptor)
        val vpnOutput = FileOutputStream(vpnInterface?.fileDescriptor)
        
        val packet = ByteBuffer.allocate(32767)
        
        try {
            // Create UDP channel for communication with V2Ray server
            val tunnel = DatagramChannel.open()
            tunnel.connect(InetSocketAddress(serverAddress, serverPort))
            protect(tunnel.socket()) // Protect from VPN routing
            
            while (isConnected && !Thread.currentThread().isInterrupted) {
                // Read packet from VPN interface
                val length = vpnInput.read(packet.array())
                
                if (length > 0) {
                    // In real implementation:
                    // 1. Encrypt packet using VMess/VLESS protocol
                    // 2. Send to V2Ray server
                    // 3. Receive response
                    // 4. Decrypt and write back to VPN interface
                    
                    packet.limit(length)
                    // tunnel.write(packet) // Send to server
                    packet.clear()
                }
                
                // Small delay to prevent CPU spinning
                Thread.sleep(10)
            }
            
            tunnel.close()
            
        } catch (e: Exception) {
            Log.e(TAG, "VPN loop error: ${e.message}")
        } finally {
            vpnInput.close()
            vpnOutput.close()
        }
    }
    
    private fun stopVpn() {
        Log.d(TAG, "Stopping VPN")
        isConnected = false
        isRunning = false
        
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface: ${e.message}")
        }
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "VPN Service destroyed")
        stopVpn()
    }
    
    override fun onRevoke() {
        super.onRevoke()
        Log.d(TAG, "VPN permission revoked")
        stopVpn()
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
            .setContentTitle("BVPN")
            .setContentText(status)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }
}

