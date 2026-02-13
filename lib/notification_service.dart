
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:notification/chat_page.dart';
import 'package:notification/main.dart';

class NotificationService {
  late final FirebaseMessaging _firebaseMessaging;

  Future<void> init() async {
    _firebaseMessaging = FirebaseMessaging.instance;
    await _firebaseMessaging.requestPermission();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle foreground messages if needed
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const ChatPage()));
    });
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
