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
  
  Timer? _speedUpdateTimer;
  Timer? _bandwidthSyncTimer;
  String? _currentServerId;
  String? _deviceId;
  
  // Track bandwidth for session
  int _sessionDownloadBytes = 0;
  int _sessionUploadBytes = 0;
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

  /// Start simulating VPN connection speeds (for demo purposes)
  /// In production, this would read actual network interface bytes
  void startSpeedMonitoring(String serverId, String deviceId) {
    _currentServerId = serverId;
    _deviceId = deviceId;
    _sessionStartTime = DateTime.now();
    _sessionDownloadBytes = 0;
    _sessionUploadBytes = 0;
    
    // Simulate speed updates every second
    _speedUpdateTimer?.cancel();
    _speedUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateSpeeds();
    });
    
    // Sync bandwidth to Firebase every 30 seconds
    _bandwidthSyncTimer?.cancel();
    _bandwidthSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _syncBandwidthToFirebase();
    });
    
    debugPrint('📊 Speed monitoring started for server: $serverId');
  }

  void _updateSpeeds() {
    // Simulate realistic VPN speeds with some variation
    final random = Random();
    
    // Base speeds (adjust based on "connection quality")
    final baseDownload = 50.0 + random.nextDouble() * 150; // 50-200 KB/s
    final baseUpload = 20.0 + random.nextDouble() * 80; // 20-100 KB/s
    
    // Add some randomness for realistic feel
    downloadSpeed.value = baseDownload + (random.nextDouble() - 0.5) * 20;
    uploadSpeed.value = baseUpload + (random.nextDouble() - 0.5) * 10;
    
    // Track bandwidth used
    _sessionDownloadBytes += (downloadSpeed.value * 1024).toInt();
    _sessionUploadBytes += (uploadSpeed.value * 1024).toInt();
    totalBandwidthUsed.value = _sessionDownloadBytes + _sessionUploadBytes;
  }

  Future<void> _syncBandwidthToFirebase() async {
    if (_currentServerId == null || _deviceId == null) return;
    
    try {
      final batch = _firestore.batch();
      
      // Update server bandwidth usage
      final serverRef = _firestore.collection('servers').doc(_currentServerId);
      batch.update(serverRef, {
        'bandwidthUsed': FieldValue.increment(totalBandwidthUsed.value),
        'totalConnections': FieldValue.increment(1),
        'lastActivity': FieldValue.serverTimestamp(),
      });
      
      // Update device data usage
      final deviceRef = _firestore.collection('devices').doc(_deviceId);
      batch.update(deviceRef, {
        'dataUsage': FieldValue.increment(totalBandwidthUsed.value),
        'lastVpnActivity': FieldValue.serverTimestamp(),
      });
      
      // Log connection session
      final sessionRef = _firestore.collection('vpn_sessions').doc();
      batch.set(sessionRef, {
        'deviceId': _deviceId,
        'serverId': _currentServerId,
        'downloadBytes': _sessionDownloadBytes,
        'uploadBytes': _sessionUploadBytes,
        'totalBytes': totalBandwidthUsed.value,
        'startTime': _sessionStartTime,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      debugPrint('📊 Bandwidth synced: ${_formatBytes(totalBandwidthUsed.value)}');
    } catch (e) {
      debugPrint('❌ Failed to sync bandwidth: $e');
    }
  }

  /// Stop speed monitoring
  void stopSpeedMonitoring() {
    // Final sync before stopping
    _syncBandwidthToFirebase();
    
    _speedUpdateTimer?.cancel();
    _bandwidthSyncTimer?.cancel();
    _speedUpdateTimer = null;
    _bandwidthSyncTimer = null;
    
    // Reset values
    pingMs.value = 0;
    downloadSpeed.value = 0.0;
    uploadSpeed.value = 0.0;
    
    debugPrint('📊 Speed monitoring stopped. Total bandwidth: ${_formatBytes(totalBandwidthUsed.value)}');
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

