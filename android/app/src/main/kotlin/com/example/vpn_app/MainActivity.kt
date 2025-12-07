package com.example.vpn_app

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.RemoteViews
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Timer
import java.util.TimerTask

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.vpn_app/notification"
    private val VPN_CHANNEL = "com.example.vpn_app/vpn"
    private val NOTIFICATION_CHANNEL_ID = "vpn_status_channel_v2"
    private val NOTIFICATION_ID = 1
    private val PERMISSION_REQUEST_CODE = 100
    private val VPN_PERMISSION_REQUEST_CODE = 101

    private var timer: Timer? = null
    private var remainingSeconds: Long = 0
    private var currentLocation = "Unknown"
    private var currentFlag = "🏳️"
    private var isRunning = false
    private var showTimer = true
    
    // VPN connection parameters (stored for after permission grant)
    private var pendingVpnResult: MethodChannel.Result? = null
    private var pendingServerAddress: String? = null
    private var pendingServerPort: Int = 443
    private var pendingProtocol: String = "ws"
    private var pendingUuid: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        requestNotificationPermission()
        
        // Notification Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startNotification" -> {
                    val location = call.argument<String>("location") ?: "Unknown"
                    val flag = call.argument<String>("flag") ?: "🏳️"
                    val remaining = call.argument<Int>("remaining_seconds")?.toLong() ?: 0
                    val timerVisible = call.argument<Boolean>("show_timer") ?: true
                    startNotification(location, flag, remaining, timerVisible)
                    result.success(null)
                }
                "stopNotification" -> {
                    stopNotification()
                    result.success(null)
                }
                "updateNotificationTime" -> {
                    val remaining = call.argument<Int>("remaining_seconds")?.toLong() ?: remainingSeconds
                    updateNotificationTime(remaining)
                    result.success(null)
                }
                "updateShowTimer" -> {
                    val timerVisible = call.argument<Boolean>("show_timer") ?: true
                    updateShowTimer(timerVisible)
                    result.success(null)
                }
                "requestPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // VPN Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestVpnPermission" -> {
                    requestVpnPermission(result)
                }
                "connectVpn" -> {
                    val serverAddress = call.argument<String>("server_address") ?: ""
                    val serverPort = call.argument<Int>("server_port") ?: 443
                    val protocol = call.argument<String>("protocol") ?: "ws"
                    val uuid = call.argument<String>("uuid") ?: ""
                    
                    connectVpn(serverAddress, serverPort, protocol, uuid, result)
                }
                "disconnectVpn" -> {
                    disconnectVpn()
                    result.success(mapOf("success" to true))
                }
                "isVpnConnected" -> {
                    result.success(BvpnVpnService.isRunning)
                }
                "hasVpnPermission" -> {
                    val intent = VpnService.prepare(this)
                    result.success(intent == null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun requestVpnPermission(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            // Need to request permission
            pendingVpnResult = result
            startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
        } else {
            // Already have permission
            result.success(mapOf("granted" to true))
        }
    }
    
    private fun connectVpn(serverAddress: String, serverPort: Int, protocol: String, uuid: String, result: MethodChannel.Result) {
        Log.d("MainActivity", "Connecting VPN to $serverAddress:$serverPort via $protocol")
        
        // Check VPN permission first
        val intent = VpnService.prepare(this)
        if (intent != null) {
            // Need permission - store params and request
            pendingVpnResult = result
            pendingServerAddress = serverAddress
            pendingServerPort = serverPort
            pendingProtocol = protocol
            pendingUuid = uuid
            startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
            return
        }
        
        // Start VPN service
        startVpnService(serverAddress, serverPort, protocol, uuid)
        result.success(mapOf("success" to true))
    }
    
    private fun startVpnService(serverAddress: String, serverPort: Int, protocol: String, uuid: String) {
        val serviceIntent = Intent(this, BvpnVpnService::class.java).apply {
            action = "CONNECT"
            putExtra("server_address", serverAddress)
            putExtra("server_port", serverPort)
            putExtra("protocol", protocol)
            putExtra("uuid", uuid)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
    
    private fun disconnectVpn() {
        Log.d("MainActivity", "Disconnecting VPN")
        val serviceIntent = Intent(this, BvpnVpnService::class.java).apply {
            action = "DISCONNECT"
        }
        startService(serviceIntent)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                Log.d("MainActivity", "VPN permission granted")
                
                // If we have pending connection params, connect now
                if (pendingServerAddress != null && pendingUuid != null) {
                    startVpnService(pendingServerAddress!!, pendingServerPort, pendingProtocol, pendingUuid!!)
                    pendingVpnResult?.success(mapOf("success" to true))
                } else {
                    pendingVpnResult?.success(mapOf("granted" to true))
                }
            } else {
                Log.d("MainActivity", "VPN permission denied")
                pendingVpnResult?.success(mapOf("granted" to false, "success" to false, "error" to "Permission denied"))
            }
            
            // Clear pending data
            pendingVpnResult = null
            pendingServerAddress = null
            pendingUuid = null
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) 
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    PERMISSION_REQUEST_CODE
                )
            }
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == 
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun startNotification(location: String, flag: String, remaining: Long, timerVisible: Boolean = true) {
        if (isRunning) return
        
        if (!hasNotificationPermission()) {
            requestNotificationPermission()
        }
        
        isRunning = true
        currentLocation = location
        currentFlag = flag
        remainingSeconds = remaining
        showTimer = timerVisible

        createNotificationChannel()
        startTimer()
    }

    private fun stopNotification() {
        isRunning = false
        timer?.cancel()
        timer = null
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }

    private fun updateNotificationTime(newRemainingSeconds: Long) {
        // Only update if there's a significant difference (more than 60 seconds)
        // This handles admin adjustments
        if (Math.abs(newRemainingSeconds - remainingSeconds) > 60) {
            remainingSeconds = newRemainingSeconds
            if (isRunning) {
                updateNotification()
            }
        }
    }

    private fun updateShowTimer(timerVisible: Boolean) {
        showTimer = timerVisible
        if (isRunning) {
            updateNotification()
        }
    }

    private fun startTimer() {
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                if (!isRunning) {
                    cancel()
                    return
                }
                Handler(Looper.getMainLooper()).post {
                    updateNotification()
                }
            }
        }, 0, 1000)
    }

    private fun updateNotification() {
        if (!hasNotificationPermission()) return
        
        try {
            if (remainingSeconds > 0) {
                remainingSeconds--
            }

            val h = remainingSeconds / 3600
            val m = (remainingSeconds % 3600) / 60
            val s = remainingSeconds % 60

            val notificationLayout = RemoteViews(packageName, R.layout.custom_notification)
            notificationLayout.setTextViewText(R.id.tv_location, currentLocation)
            notificationLayout.setTextViewText(R.id.tv_flag, currentFlag)
            
            // Show/Hide timer section based on SDUI config
            val timerVisibility = if (showTimer) android.view.View.VISIBLE else android.view.View.GONE
            notificationLayout.setViewVisibility(R.id.timer_section, timerVisibility)
            
            if (showTimer) {
                notificationLayout.setTextViewText(R.id.tv_hours, h.toString())
                notificationLayout.setTextViewText(R.id.tv_minutes, String.format("%02d", m))
                notificationLayout.setTextViewText(R.id.tv_seconds, String.format("%02d", s))
                
                // Dynamic Colors
                val blueColor = android.graphics.Color.parseColor("#448AFF")
                val greyColor = android.graphics.Color.parseColor("#888888")

                // Hours Style
                if (h > 0) {
                    notificationLayout.setInt(R.id.tv_hours, "setBackgroundResource", R.drawable.circle_bg_active)
                    notificationLayout.setTextColor(R.id.tv_hours, blueColor)
                } else {
                    notificationLayout.setInt(R.id.tv_hours, "setBackgroundResource", R.drawable.circle_bg)
                    notificationLayout.setTextColor(R.id.tv_hours, greyColor)
                }

                // Minutes Style
                if (m > 0 || h > 0) {
                    notificationLayout.setInt(R.id.tv_minutes, "setBackgroundResource", R.drawable.circle_bg_active)
                    notificationLayout.setTextColor(R.id.tv_minutes, blueColor)
                } else {
                    notificationLayout.setInt(R.id.tv_minutes, "setBackgroundResource", R.drawable.circle_bg)
                    notificationLayout.setTextColor(R.id.tv_minutes, greyColor)
                }

                // Seconds Style
                if (remainingSeconds > 0) {
                    notificationLayout.setInt(R.id.tv_seconds, "setBackgroundResource", R.drawable.circle_bg_active)
                    notificationLayout.setTextColor(R.id.tv_seconds, blueColor)
                } else {
                    notificationLayout.setInt(R.id.tv_seconds, "setBackgroundResource", R.drawable.circle_bg)
                    notificationLayout.setTextColor(R.id.tv_seconds, greyColor)
                }
            }
            
            val downSpeed = (1..50).random()
            val upSpeed = (1..20).random()
            notificationLayout.setTextViewText(R.id.tv_download, "$downSpeed MB/s")
            notificationLayout.setTextViewText(R.id.tv_upload, "$upSpeed MB/s")
            notificationLayout.setTextViewText(R.id.tv_ping, "${(20..150).random()}ms")

            val intent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)

            val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(notificationLayout)
                .setCustomBigContentView(notificationLayout)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .build()

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            e.printStackTrace()
            // Fallback
            val intent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
            
            val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("SafeVPN Connected")
                .setContentText("VPN is running - $currentLocation")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .build()
                
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "VPN Status"
            val descriptionText = "Shows VPN connection status"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}