import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// VPN Speed Service - Measures ping, download/upload speeds, and tracks bandwidth
class VpnSpeedService {
  static final VpnSpeedService _instance = VpnSpeedService._internal();
  factory VpnSpeedService() => _instance;
  VpnSpeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Notifiers for real-time UI updates
  final ValueNotifier<int> pingMs = ValueNotifier<int>(0);
  final ValueNotifier<double> downloadSpeed = ValueNotifier<double>(0.0); // KB/s
  final ValueNotifier<double> uploadSpeed = ValueNotifier<double>(0.0); // KB/s
  final ValueNotifier<int> totalBandwidthUsed = ValueNotifier<int>(0); // bytes
  
  // Real Server Stats
  final ValueNotifier<int> serverTotalBandwidth = ValueNotifier<int>(0);
  final ValueNotifier<String> serverLoadStatus = ValueNotifier<String>('Low'); // Low, Medium, High
  
  Timer? _speedUpdateTimer;
  Timer? _bandwidthSyncTimer;
  Timer? _pingTimer; // For periodic ping updates
  StreamSubscription<DocumentSnapshot>? _serverStatsSubscription;
  String? _currentServerId;
  String? _deviceId;
  String? _currentServerAddress; // Store for periodic ping
  
  // Track bandwidth for session
  int _sessionDownloadBytes = 0;
  int _sessionUploadBytes = 0;
  int _lastSyncedDownloadBytes = 0; // Track last synced for delta calculation
  int _lastSyncedUploadBytes = 0;
  DateTime? _sessionStartTime;

  /// Measure ping to a server address
  /// [port] - Optional port to use, defaults to 443
  Future<int> measurePing(String address, {int? port}) async {
    try {
      final targetPort = port ?? 443;
      final stopwatch = Stopwatch()..start();
      
      // Try TCP connection to specified port
      Socket? socket;
      try {
        socket = await Socket.connect(
          address, 
          targetPort, 
          timeout: const Duration(seconds: 3),
        );
        socket.destroy();
      } catch (_) {
        // Try fallback ports
        final fallbackPorts = [443, 8443, 4434].where((p) => p != targetPort).toList();
        for (final fallbackPort in fallbackPorts) {
          try {
            socket = await Socket.connect(
              address, 
              fallbackPort, 
              timeout: const Duration(seconds: 3),
            );
            socket.destroy();
            break;
          } catch (_) {
            continue;
          }
        }
        if (socket == null) {
          // If all connections fail, return high latency
          return 999;
        }
      }
      
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      debugPrint('❌ Ping error: $e');
      return 999;
    }
  }

  /// Measure ping for all servers and update their latency in Firebase
  Future<Map<String, int>> measureAllServerPings(List<Map<String, dynamic>> servers) async {
    final Map<String, int> results = {};
    
    for (final server in servers) {
      final address = server['address'] as String?;
      final serverId = server['id'] as String?;
      
      if (address != null && serverId != null) {
        final ping = await measurePing(address);
        results[serverId] = ping;
        
        // Update Firebase with latency
        try {
          await _firestore.collection('servers').doc(serverId).update({
            'latency': ping,
            'lastPingCheck': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Failed to update server latency: $e');
        }
      }
    }
    
    return results;
  }

  /// Start speed monitoring with real data handling
  void startSpeedMonitoring(String serverId, String deviceId, {String? serverAddress}) {
    _currentServerId = serverId;
    _deviceId = deviceId;
    _currentServerAddress = serverAddress;
    _sessionStartTime = DateTime.now();
    _sessionDownloadBytes = 0;
    _sessionUploadBytes = 0;
    _lastSyncedDownloadBytes = 0;
    _lastSyncedUploadBytes = 0;
    
    // Stop existing timers
    _speedUpdateTimer?.cancel();
    _pingTimer?.cancel();
    
    // Increment server connection count ONCE when connection starts
    _incrementServerConnectionCount(serverId);
    
    // Start listening to real server stats from Firestore
    _startServerStatsListener(serverId);
    
    // Sync bandwidth DELTA to Firestore periodically (every 30 seconds)
    _bandwidthSyncTimer?.cancel();
    _bandwidthSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _syncBandwidthToFirebase();
    });
    
    // Start periodic ping measurement (every 10 seconds)
    if (serverAddress != null && serverAddress.isNotEmpty) {
      _startPeriodicPing(serverAddress);
    }
    
    debugPrint('📊 Real Speed monitoring started for server: $serverId');
  }
  
  /// Increment server connection count when a new connection starts
  Future<void> _incrementServerConnectionCount(String serverId) async {
    try {
      await _firestore.collection('servers').doc(serverId).update({
        'totalConnections': FieldValue.increment(1),
      });
      debugPrint('📊 Server connection count incremented');
    } catch (e) {
      debugPrint('❌ Failed to increment connection count: $e');
    }
  }
  
  /// Start periodic ping measurement
  void _startPeriodicPing(String address) {
    debugPrint('🏓 Starting periodic ping to: $address');
    _pingTimer?.cancel();
    // Measure immediately
    updatePingForServer(address);
    // Then every 10 seconds
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      updatePingForServer(address);
    });
  }

  // Track previous cumulative bytes for speed calculation fallback
  int _prevDownloadBytes = 0;
  int _prevUploadBytes = 0;
  DateTime? _lastSpeedUpdateTime;
  
  // Called from UI when V2Ray plugin reports status updates
  void updateRealTimeStatus(int downloadSpeedBytes, int uploadSpeedBytes, int ping, int uploadBytes, int downloadBytes) {
    // If ping is provided (and > 0), use it. Otherwise keep existing value (measured separately)
    if (ping > 0) {
      pingMs.value = ping;
    }
    
    // Calculate speeds from cumulative bytes if instant speed is 0
    double dlSpeed = downloadSpeedBytes / 1024.0;
    double ulSpeed = uploadSpeedBytes / 1024.0;
    
    // If plugin reports 0 speeds but we have cumulative bytes, calculate manually
    if ((dlSpeed < 0.1 || ulSpeed < 0.1) && _lastSpeedUpdateTime != null) {
      final now = DateTime.now();
      final timeDiffMs = now.difference(_lastSpeedUpdateTime!).inMilliseconds;
      
      if (timeDiffMs > 0 && timeDiffMs < 5000) { // Only if < 5 seconds since last update
        final dlDelta = downloadBytes - _prevDownloadBytes;
        final ulDelta = uploadBytes - _prevUploadBytes;
        
        if (dlDelta > 0 && dlSpeed < 0.1) {
          // Calculate bytes per second, then convert to KB/s
          dlSpeed = (dlDelta / (timeDiffMs / 1000.0)) / 1024.0;
        }
        if (ulDelta > 0 && ulSpeed < 0.1) {
          ulSpeed = (ulDelta / (timeDiffMs / 1000.0)) / 1024.0;
        }
      }
    }
    
    downloadSpeed.value = dlSpeed;
    uploadSpeed.value = ulSpeed;
    
    // Update tracking for next calculation
    _prevDownloadBytes = downloadBytes;
    _prevUploadBytes = uploadBytes;
    _lastSpeedUpdateTime = DateTime.now();
    
    // Update total usage
    if (uploadBytes > 0 || downloadBytes > 0) {
       int newTotal = uploadBytes + downloadBytes;
       totalBandwidthUsed.value = newTotal;
       _sessionUploadBytes = uploadBytes;
       _sessionDownloadBytes = downloadBytes;
    }
    
    debugPrint('📊 Speed Update: dl=${dlSpeed.toStringAsFixed(1)}KB/s, ul=${ulSpeed.toStringAsFixed(1)}KB/s, total=${_formatBytes(totalBandwidthUsed.value)}');
  }
  
  // Make public for usage
  String formatBytes(int bytes) {
    return _formatBytes(bytes);
  }

  void _startServerStatsListener(String serverId) {
    _serverStatsSubscription?.cancel();
    _serverStatsSubscription = _firestore
        .collection('servers')
        .doc(serverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final bandwidth = (data['bandwidthUsed'] as num?)?.toInt() ?? 0;
          serverTotalBandwidth.value = bandwidth;
          
          // Calculate load status (mock threshold: 1TB = High)
          // In real world, this would depend on server capacity
          if (bandwidth > 1024 * 1024 * 1024 * 1024) { // 1TB
            serverLoadStatus.value = 'High';
          } else if (bandwidth > 1024 * 1024 * 1024 * 100) { // 100GB
            serverLoadStatus.value = 'Medium';
          } else {
            serverLoadStatus.value = 'Low';
          }
        }
      }
    }, onError: (e) {
      debugPrint('❌ Error listening to server stats: $e');
    });
  }

  /* 
  // Simulated speed update - Removed for Real V2Ray
  void _updateSpeeds() {
    // ...
  }
  */

  Future<void> _syncBandwidthToFirebase() async {
    if (_currentServerId == null || _deviceId == null) return;
    
    // Calculate delta (new bytes since last sync)
    final downloadDelta = _sessionDownloadBytes - _lastSyncedDownloadBytes;
    final uploadDelta = _sessionUploadBytes - _lastSyncedUploadBytes;
    final totalDelta = downloadDelta + uploadDelta;
    
    // Only sync if there's new data
    if (totalDelta <= 0) {
      debugPrint('📊 No new bandwidth to sync');
      return;
    }
    
    try {
      final batch = _firestore.batch();
      
      // Update server bandwidth usage with DELTA (not total)
      final serverRef = _firestore.collection('servers').doc(_currentServerId);
      batch.update(serverRef, {
        'bandwidthUsed': FieldValue.increment(totalDelta),
        'lastActivity': FieldValue.serverTimestamp(),
      });
      
      // Update device data usage with DELTA
      final deviceRef = _firestore.collection('devices').doc(_deviceId);
      batch.update(deviceRef, {
        'dataUsage': FieldValue.increment(totalDelta),
        'lastVpnActivity': FieldValue.serverTimestamp(),
      });
      
      // Log connection session (update or create)
      final sessionId = '${_deviceId}_${_sessionStartTime?.millisecondsSinceEpoch ?? 0}';
      final sessionRef = _firestore.collection('vpn_sessions').doc(sessionId);
      batch.set(sessionRef, {
        'deviceId': _deviceId,
        'serverId': _currentServerId,
        'downloadBytes': _sessionDownloadBytes,
        'uploadBytes': _sessionUploadBytes,
        'totalBytes': totalBandwidthUsed.value,
        'startTime': _sessionStartTime,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      await batch.commit();
      
      // Update last synced values for next delta calculation
      _lastSyncedDownloadBytes = _sessionDownloadBytes;
      _lastSyncedUploadBytes = _sessionUploadBytes;
      
      debugPrint('📊 Bandwidth delta synced: +${_formatBytes(totalDelta)} (total: ${_formatBytes(totalBandwidthUsed.value)})');
    } catch (e) {
      debugPrint('❌ Failed to sync bandwidth: $e');
    }
  }

  /// Stop speed monitoring
  Future<void> stopSpeedMonitoring() async {
    debugPrint('📊 Stopping speed monitoring...');
    
    // Store serverId before clearing (important for decrement)
    final serverId = _currentServerId;
    
    // Cancel timers first
    _speedUpdateTimer?.cancel();
    _bandwidthSyncTimer?.cancel();
    _pingTimer?.cancel();
    _serverStatsSubscription?.cancel();
    _speedUpdateTimer = null;
    _bandwidthSyncTimer = null;
    _pingTimer = null;
    _serverStatsSubscription = null;
    
    // Final sync before stopping (await to ensure completion)
    await _syncBandwidthToFirebase();
    
    // Decrement server connection count when disconnecting (await to ensure completion)
    if (serverId != null) {
      debugPrint('📊 Decrementing connection count for server: $serverId');
      await _decrementServerConnectionCount(serverId);
      debugPrint('📊 Connection count decremented successfully');
    } else {
      debugPrint('⚠️ No serverId found, cannot decrement connection count');
    }
    
    _currentServerAddress = null;
    _currentServerId = null;
    
    // Reset sync tracking
    _lastSyncedDownloadBytes = 0;
    _lastSyncedUploadBytes = 0;
    
    // Reset speed calculation tracking
    _prevDownloadBytes = 0;
    _prevUploadBytes = 0;
    _lastSpeedUpdateTime = null;
    
    // Reset values
    pingMs.value = 0;
    downloadSpeed.value = 0.0;
    uploadSpeed.value = 0.0;
    totalBandwidthUsed.value = 0; // Reset for next session
    
    debugPrint('📊 Speed monitoring stopped. Session ended.');
  }
  
  /// Decrement server connection count when disconnecting (minimum 0)
  Future<void> _decrementServerConnectionCount(String serverId) async {
    try {
      // Use transaction to ensure count doesn't go below 0
      await _firestore.runTransaction((transaction) async {
        final serverDoc = await transaction.get(
          _firestore.collection('servers').doc(serverId)
        );
        
        if (serverDoc.exists) {
          final currentCount = (serverDoc.data()?['totalConnections'] as num?)?.toInt() ?? 0;
          final newCount = currentCount > 0 ? currentCount - 1 : 0;
          
          transaction.update(serverDoc.reference, {
            'totalConnections': newCount,
          });
        }
      });
      debugPrint('📊 Server connection count decremented');
    } catch (e) {
      debugPrint('❌ Failed to decrement connection count: $e');
    }
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get formatted download speed string
  String get downloadSpeedString {
    final speed = downloadSpeed.value;
    if (speed < 1) return '0 B/s';
    if (speed < 1024) return '${speed.toStringAsFixed(1)} KB/s';
    return '${(speed / 1024).toStringAsFixed(1)} MB/s';
  }

  /// Get formatted upload speed string
  String get uploadSpeedString {
    final speed = uploadSpeed.value;
    if (speed < 1) return '0 B/s';
    if (speed < 1024) return '${speed.toStringAsFixed(1)} KB/s';
    return '${(speed / 1024).toStringAsFixed(1)} MB/s';
  }

  /// Get formatted bandwidth string
  String get bandwidthString => _formatBytes(totalBandwidthUsed.value);

  /// Measure ping and update notifier
  Future<void> updatePingForServer(String address) async {
    final ping = await measurePing(address);
    pingMs.value = ping;
    debugPrint('🏓 Ping to $address: ${ping}ms');
  }

  /// Get bandwidth statistics for a device
  Future<Map<String, dynamic>> getDeviceBandwidthStats(String deviceId) async {
    try {
      final sessions = await _firestore
          .collection('vpn_sessions')
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('lastUpdate', descending: true)
          .limit(100)
          .get();
      
      int totalDownload = 0;
      int totalUpload = 0;
      int sessionCount = sessions.docs.length;
      
      for (final doc in sessions.docs) {
        totalDownload += (doc.data()['downloadBytes'] as num?)?.toInt() ?? 0;
        totalUpload += (doc.data()['uploadBytes'] as num?)?.toInt() ?? 0;
      }
      
      return {
        'totalDownload': totalDownload,
        'totalUpload': totalUpload,
        'totalBandwidth': totalDownload + totalUpload,
        'sessionCount': sessionCount,
        'totalDownloadFormatted': _formatBytes(totalDownload),
        'totalUploadFormatted': _formatBytes(totalUpload),
        'totalBandwidthFormatted': _formatBytes(totalDownload + totalUpload),
      };
    } catch (e) {
      debugPrint('❌ Error getting bandwidth stats: $e');
      return {};
    }
  }

  /// Get server bandwidth statistics
  Future<Map<String, dynamic>> getServerBandwidthStats(String serverId) async {
    try {
      final serverDoc = await _firestore.collection('servers').doc(serverId).get();
      
      if (serverDoc.exists) {
        final data = serverDoc.data()!;
        final bandwidthUsed = (data['bandwidthUsed'] as num?)?.toInt() ?? 0;
        final totalConnections = (data['totalConnections'] as num?)?.toInt() ?? 0;
        
        return {
          'bandwidthUsed': bandwidthUsed,
          'bandwidthFormatted': _formatBytes(bandwidthUsed),
          'totalConnections': totalConnections,
          'avgBandwidthPerConnection': totalConnections > 0 
              ? _formatBytes(bandwidthUsed ~/ totalConnections) 
              : '0 B',
        };
      }
      
      return {};
    } catch (e) {
      debugPrint('❌ Error getting server bandwidth stats: $e');
      return {};
    }
  }
}

