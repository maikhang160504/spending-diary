import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../screens/chat/chat_screen.dart';
import 'push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
  await PushNotificationService.instance.initialize();
  await PushNotificationService.instance.showFromRemoteMessage(message);
}

/// Registers FCM token with backend and routes push taps to navigation.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  FirebaseMessaging? _messaging;
  void Function(String deepLink)? _onDeepLink;
  Future<void> Function(String token, String platform)? _registerToken;
  Future<void> Function(String token)? _removeToken;
  bool _initialized = false;
  String? _currentToken;

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize({
    required Future<void> Function(String token, String platform) registerToken,
    Future<void> Function(String token)? removeToken,
    void Function(String deepLink)? onDeepLink,
  }) async {
    if (!isSupported) return;

    _registerToken = registerToken;
    _removeToken = removeToken;
    _onDeepLink = onDeepLink;

    if (_initialized) {
      // Khi đăng nhập lại hoặc chuyển tài khoản, tái đồng bộ FCM token cho user hiện tại
      await syncCurrentToken();
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      debugPrint('[FCM] Firebase init failed: $e');
      if (Firebase.apps.isEmpty) {
        return;
      }
    }

    _messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging!.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    _messaging!.onTokenRefresh.listen(_syncToken);

    final initial = await _messaging!.getInitialMessage();
    if (initial != null) {
      _handleDeepLink(initial.data['deepLink']);
    }

    final token = await _messaging!.getToken();
    if (token != null) {
      await _syncToken(token);
    }

    _initialized = true;
    debugPrint('[FCM] initialized');
  }

  Future<void> syncCurrentToken() async {
    if (!isSupported) return;
    try {
      _messaging ??= FirebaseMessaging.instance;
      final token = await _messaging!.getToken();
      if (token != null) {
        await _syncToken(token);
      }
    } catch (e) {
      debugPrint('[FCM] syncCurrentToken failed: $e');
    }
  }

  Future<void> unregisterCurrentToken() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await _removeToken?.call(token);
      await _messaging?.deleteToken();
      _currentToken = null;
    } catch (e) {
      debugPrint('[FCM] unregister failed: $e');
    }
  }

  Future<void> _syncToken(String token) async {
    _currentToken = token;
    final register = _registerToken;
    if (register == null) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await register(token, platform);
    } catch (e) {
      debugPrint('[FCM] token register failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final type = (message.data['type'] as String?)?.toLowerCase();
    if (type == 'chat_reply') {
      if (ChatScreen.isActive) {
        debugPrint(
          '[FCM] Suppressing CHAT_REPLY because user is on chat screen',
        );
        return;
      }
    }
    PushNotificationService.instance.showFromRemoteMessage(message);
  }

  void _onMessageOpened(RemoteMessage message) {
    _handleDeepLink(message.data['deepLink']);
  }

  void _handleDeepLink(String? deepLink) {
    if (deepLink == null || deepLink.isEmpty) return;
    _onDeepLink?.call(deepLink);
  }
}
