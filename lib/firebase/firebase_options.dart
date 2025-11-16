import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDNsY1tB0O-EoGlhIB9lqrMvr4tcE44Ik8",
    authDomain: "safe-tourism-cartagena.firebaseapp.com",
    projectId: "safe-tourism-cartagena",
    storageBucket: "safe-tourism-cartagena.firebasestorage.app",
    messagingSenderId: "326339524473",
    appId: "1:326339524473:web:b732b5fd31f3b5500c61a8",
    measurementId: "G-7FJT370PDV"
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDNsY1tB0O-EoGlhIB9lqrMvr4tcE44Ik8",
    appId: "1:326339524473:web:b732b5fd31f3b5500c61a8",
    messagingSenderId: "326339524473",
    projectId: "safe-tourism-cartagena",
    storageBucket: "safe-tourism-cartagena.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:"AIzaSyDNsY1tB0O-EoGlhIB9lqrMvr4tcE44Ik8",
    appId: "1:326339524473:web:b732b5fd31f3b5500c61a8",
    messagingSenderId: "326339524473",
    projectId: "safe-tourism-cartagena",
    storageBucket: "safe-tourism-cartagena.firebasestorage.app",
  );
}