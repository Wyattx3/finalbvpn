// Firebase configuration for BVPN App
// Project: strategic-volt-341100
// Auto-generated from Firebase Console

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDQWQKLoDkYgghVpE8in35HmuyFWFwHHls',
    appId: '1:890572946148:web:b3ef65f3734c855129caf1',
    messagingSenderId: '890572946148',
    projectId: 'strategic-volt-341100',
    authDomain: 'strategic-volt-341100.firebaseapp.com',
    storageBucket: 'strategic-volt-341100.firebasestorage.app',
    measurementId: 'G-8HN9QCVF0S',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBE4E5PkSINjKQps303Up_kJvDC7Bzp2P4',
    appId: '1:890572946148:android:d33b990a80a4da8629caf1',
    messagingSenderId: '890572946148',
    projectId: 'strategic-volt-341100',
    storageBucket: 'strategic-volt-341100.firebasestorage.app',
  );

  // iOS - Add your iOS app from Firebase Console for this config
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQWQKLoDkYgghVpE8in35HmuyFWFwHHls',
    appId: '1:890572946148:web:b3ef65f3734c855129caf1',
    messagingSenderId: '890572946148',
    projectId: 'strategic-volt-341100',
    storageBucket: 'strategic-volt-341100.firebasestorage.app',
    iosBundleId: 'com.example.vpnApp',
  );

  // macOS - Uses iOS config
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDQWQKLoDkYgghVpE8in35HmuyFWFwHHls',
    appId: '1:890572946148:web:b3ef65f3734c855129caf1',
    messagingSenderId: '890572946148',
    projectId: 'strategic-volt-341100',
    storageBucket: 'strategic-volt-341100.firebasestorage.app',
    iosBundleId: 'com.example.vpnApp',
  );

  // Windows - Uses Web config
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDQWQKLoDkYgghVpE8in35HmuyFWFwHHls',
    appId: '1:890572946148:web:b3ef65f3734c855129caf1',
    messagingSenderId: '890572946148',
    projectId: 'strategic-volt-341100',
    authDomain: 'strategic-volt-341100.firebaseapp.com',
    storageBucket: 'strategic-volt-341100.firebasestorage.app',
  );

  // Linux - Uses Web config
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyDQWQKLoDkYgghVpE8in35HmuyFWFwHHls',
    appId: '1:890572946148:web:b3ef65f3734c855129caf1',
    messagingSenderId: '890572946148',
    projectId: 'strategic-volt-341100',
    authDomain: 'strategic-volt-341100.firebaseapp.com',
    storageBucket: 'strategic-volt-341100.firebasestorage.app',
  );
}
