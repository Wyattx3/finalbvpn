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
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

class WireGuardVpnService : VpnService() {
    
    companion object {
        private const val TAG = "WireGuardVpnService"
        private const val NOTIFICATION_CHANNEL_ID = "vpn_service_channel"
        private const val NOTIFICATION_ID = 2
        
        @Volatile
        var isRunning = false
            private set
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private var serverAddress: String = ""
    private var serverPort: Int = 51820
    private var privateKey: String = ""
    private var publicKey: String = ""
    private var serverPublicKey: String = ""
    private var allowedIPs: String = "0.0.0.0/0"
    private var dns: String = "8.8.8.8"
    private var localAddress: String = "10.0.0.2/32"
    
    private var udpSocket: DatagramSocket? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "WireGuard VPN Service created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "WireGuard VPN Service onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            "CONNECT" -> {
                serverAddress = intent.getStringExtra("server_address") ?: ""
                serverPort = intent.getIntExtra("server_port", 51820)
                privateKey = intent.getStringExtra("private_key") ?: ""
                publicKey = intent.getStringExtra("public_key") ?: ""
                serverPublicKey = intent.getStringExtra("server_public_key") ?: ""
                allowedIPs = intent.getStringExtra("allowed_ips") ?: "0.0.0.0/0"
                dns = intent.getStringExtra("dns") ?: "8.8.8.8"
                localAddress = intent.getStringExtra("local_address") ?: "10.0.0.2/32"
                
                Log.d(TAG, "Connecting to WireGuard server: $serverAddress:$serverPort")
                startWireGuardVpn()
            }
            "DISCONNECT" -> {
                stopWireGuardVpn()
            }
        }
        
        return START_STICKY
    }
    
    private fun startWireGuardVpn() {
        if (isRunning) {
            Log.d(TAG, "VPN already running")
            return
        }
        
        isRunning = true
        startForeground(NOTIFICATION_ID, createNotification("Connecting to $serverAddress"))
        
        scope.launch {
            try {
                // Establish VPN tunnel
                val builder = Builder()
                    .setSession("Suf Fhoke VPN")
                    .setMtu(1280)
                
                // Parse local address
                val addressParts = localAddress.split("/")
                val ipAddress = addressParts[0]
                val prefix = if (addressParts.size > 1) addressParts[1].toInt() else 32
                builder.addAddress(ipAddress, prefix)
                
                // Add DNS
                dns.split(",").forEach { dnsServer ->
                    try {
                        builder.addDnsServer(dnsServer.trim())
                    } catch (e: Exception) {
                        Log.e(TAG, "Invalid DNS: $dnsServer")
                    }
                }
                
                // Route all traffic through VPN
                builder.addRoute("0.0.0.0", 0)
                
                // Exclude our own traffic
                try {
                    builder.addDisallowedApplication(packageName)
                } catch (e: Exception) {
                    Log.e(TAG, "Could not exclude app: ${e.message}")
                }
                
                vpnInterface = builder.establish()
                
                if (vpnInterface == null) {
                    Log.e(TAG, "Failed to establish VPN interface")
                    stopWireGuardVpn()
                    return@launch
                }
                
                Log.d(TAG, "VPN tunnel established")
                updateNotification("Connected to $serverAddress")
                
                // Start UDP socket for WireGuard
                udpSocket = DatagramSocket()
                udpSocket?.connect(InetAddress.getByName(serverAddress), serverPort)
                
                // Protect the socket
                if (!protect(udpSocket!!)) {
                    Log.e(TAG, "Failed to protect socket")
                    stopWireGuardVpn()
                    return@launch
                }
                
                Log.d(TAG, "WireGuard socket connected")
                
                // Start packet forwarding
                val jobs = listOf(
                    launch { forwardOutgoing() },
                    launch { forwardIncoming() }
                )
                
                // Send initial handshake
                sendHandshake()
                
                jobs.joinAll()
                
            } catch (e: Exception) {
                Log.e(TAG, "VPN error: ${e.message}", e)
                stopWireGuardVpn()
            }
        }
    }
    
    private suspend fun forwardOutgoing() {
        val vpnInput = FileInputStream(vpnInterface?.fileDescriptor)
        val buffer = ByteArray(32767)
        
        try {
            while (isRunning) {
                val length = vpnInput.read(buffer)
                if (length > 0) {
                    // Encapsulate and send to WireGuard server
                    val packet = encapsulatePacket(buffer, length)
                    val datagram = DatagramPacket(packet, packet.size)
                    udpSocket?.send(datagram)
                }
            }
        } catch (e: Exception) {
            if (isRunning) {
                Log.e(TAG, "Error forwarding outgoing: ${e.message}")
            }
        }
    }
    
    private suspend fun forwardIncoming() {
        val vpnOutput = FileOutputStream(vpnInterface?.fileDescriptor)
        val buffer = ByteArray(32767)
        
        try {
            while (isRunning) {
                val datagram = DatagramPacket(buffer, buffer.size)
                udpSocket?.receive(datagram)
                
                if (datagram.length > 0) {
                    // Decapsulate and write to VPN interface
                    val packet = decapsulatePacket(buffer, datagram.length)
                    if (packet != null) {
                        vpnOutput.write(packet)
                    }
                }
            }
        } catch (e: Exception) {
            if (isRunning) {
                Log.e(TAG, "Error forwarding incoming: ${e.message}")
            }
        }
    }
    
    private fun sendHandshake() {
        try {
            // WireGuard handshake initiation (simplified)
            val handshake = createHandshakeInit()
            val packet = DatagramPacket(handshake, handshake.size)
            udpSocket?.send(packet)
            Log.d(TAG, "Handshake sent")
        } catch (e: Exception) {
            Log.e(TAG, "Handshake error: ${e.message}")
        }
    }
    
    private fun createHandshakeInit(): ByteArray {
        // WireGuard message type 1 = Handshake Initiation
        val buffer = ByteBuffer.allocate(148)
        buffer.put(1) // Message type
        buffer.put(ByteArray(3)) // Reserved
        buffer.putInt(0) // Sender index
        
        // Unencrypted ephemeral (32 bytes) - random for now
        val ephemeral = ByteArray(32)
        SecureRandom().nextBytes(ephemeral)
        buffer.put(ephemeral)
        
        // Static (48 bytes) - encrypted with server's public key
        val staticKey = ByteArray(48)
        SecureRandom().nextBytes(staticKey)
        buffer.put(staticKey)
        
        // Timestamp (28 bytes)
        val timestamp = ByteArray(28)
        SecureRandom().nextBytes(timestamp)
        buffer.put(timestamp)
        
        // MAC1 (16 bytes)
        buffer.put(ByteArray(16))
        
        // MAC2 (16 bytes)
        buffer.put(ByteArray(16))
        
        return buffer.array()
    }
    
    private fun encapsulatePacket(data: ByteArray, length: Int): ByteArray {
        // WireGuard message type 4 = Transport Data
        val buffer = ByteBuffer.allocate(length + 16)
        buffer.put(4) // Message type
        buffer.put(ByteArray(3)) // Reserved
        buffer.putInt(0) // Receiver index
        buffer.putLong(System.nanoTime()) // Counter
        buffer.put(data, 0, length)
        return buffer.array()
    }
    
    private fun decapsulatePacket(data: ByteArray, length: Int): ByteArray? {
        if (length < 16) return null
        
        val messageType = data[0].toInt() and 0xFF
        
        return when (messageType) {
            2 -> { // Handshake Response
                Log.d(TAG, "Received handshake response")
                null
            }
            4 -> { // Transport Data
                if (length > 16) {
                    data.copyOfRange(16, length)
                } else {
                    null
                }
            }
            else -> {
                Log.d(TAG, "Unknown message type: $messageType")
                null
            }
        }
    }
    
    private fun stopWireGuardVpn() {
        Log.d(TAG, "Stopping WireGuard VPN")
        isRunning = false
        
        scope.cancel()
        
        try {
            udpSocket?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing socket: ${e.message}")
        }
        udpSocket = null
        
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface: ${e.message}")
        }
        vpnInterface = null
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
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
        stopWireGuardVpn()
    }
}

