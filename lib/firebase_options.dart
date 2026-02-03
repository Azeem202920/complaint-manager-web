import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC2qkp6xSzD21A7y5jnEOiv8X4LRrK4cnY',
    appId: '1:261364073312:web:b7828fbfac14fc416f1405',
    messagingSenderId: '261364073312',
    projectId: 'complaint-manager-app-16d78',
    authDomain: 'complaint-manager-app-16d78.firebaseapp.com',
    storageBucket: 'complaint-manager-app-16d78.firebasestorage.app',
    measurementId: 'G-CHKEBHS56C',
    databaseURL: 'https://complaint-manager-app-16d78.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC2qkp6xSzD21A7y5jnEOiv8X4LRrK4cnY',
    appId: '1:261364073312:android:b7828fbfac14fc416f1405',
    messagingSenderId: '261364073312',
    projectId: 'complaint-manager-app-16d78',
    storageBucket: 'complaint-manager-app-16d78.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC2qkp6xSzD21A7y5jnEOiv8X4LRrK4cnY',
    appId: '1:261364073312:ios:b7828fbfac14fc416f1405',
    messagingSenderId: '261364073312',
    projectId: 'complaint-manager-app-16d78',
    storageBucket: 'complaint-manager-app-16d78.firebasestorage.app',
    iosBundleId: 'com.example.complaintManager',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC2qkp6xSzD21A7y5jnEOiv8X4LRrK4cnY',
    appId: '1:261364073312:ios:b7828fbfac14fc416f1405',
    messagingSenderId: '261364073312',
    projectId: 'complaint-manager-app-16d78',
    storageBucket: 'complaint-manager-app-16d78.firebasestorage.app',
    iosBundleId: 'com.example.complaintManager',
  );
}