import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  PushNotificationService._privateConstructor();
  static final PushNotificationService instance =
      PushNotificationService._privateConstructor();

  static const String _channelId = 'budget_alerts_channel';
  static const String _channelName = 'Cảnh báo ngân sách';
  static const String _channelDescription =
      'Thông báo cảnh báo ngân sách và chi tiêu định kỳ';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  void Function(String?)? _onTapCallback;

  Future<void> initialize({void Function(String?)? onNotificationTap}) async {
    if (onNotificationTap != null) {
      _onTapCallback = onNotificationTap;
    }
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        _onTapCallback?.call(details.payload);
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _isInitialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          showWhen: true,
          enableVibration: true,
          playSound: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.reminder,
        );

    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Hiển thị notification từ FCM (foreground / background handler).
  Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title =
        notification?.title ?? data['title'] as String? ?? 'SpendDiary';
    final body =
        notification?.body ??
        data['message'] as String? ??
        data['body'] as String? ??
        '';
    final deepLink = data['deepLink'] as String? ?? '/';
    final type = data['type'] as String? ?? 'GENERAL';
    final id = type.hashCode.abs() % 100000;

    await showNotification(id: id, title: title, body: body, payload: deepLink);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _localNotifications.cancelAll();
    } catch (_) {
      // Ignore errors
    }
  }
}
