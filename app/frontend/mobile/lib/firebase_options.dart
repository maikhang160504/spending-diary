import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase options for SpendDiary (Android).
/// iOS: thêm GoogleService-Info.plist rồi bổ sung ios config.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'Firebase chưa cấu hình cho ${defaultTargetPlatform.name}. '
      'Thêm GoogleService-Info.plist (iOS) hoặc chạy trên Android.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDazPGVFNBH_hu5xl-y3SQwJlpdiXfNG54',
    appId: '1:388012082045:android:be53d68c9bb0eb0a09c214',
    messagingSenderId: '388012082045',
    projectId: 'powerful-bounty-477016-u8',
    storageBucket: 'powerful-bounty-477016-u8.firebasestorage.app',
  );
}
