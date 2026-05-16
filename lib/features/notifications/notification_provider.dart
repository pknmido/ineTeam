import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../data/models/notification_model.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/user_service.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();
  final Uuid _uuid = const Uuid();

  List<NotificationModel> _notifications = [];
  StreamSubscription? _sub;
  String? _userId;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  final Set<String> _seenNotificationIds = {};
  bool _isFirstLoad = true;

  void initialize(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _sub?.cancel();
    _isFirstLoad = true;
    _notifications = [];
    
    if (userId != null) {
      _sub = _notificationService.getUserNotifications(userId).listen((data) {
        if (!_isFirstLoad) {
          for (final notification in data) {
            if (!notification.isRead && !_seenNotificationIds.contains(notification.id)) {
              // Auto-handle 'friend_accepted' to make it bi-directional automatically
              if (notification.type == 'friend_accepted') {
                handleFriendAccepted(notification.data['friendId']);
                // We keep it in the list so user sees the message, but mark as read
                markAsRead(notification.id);
              }
              
              _showLocalNotification(notification.title, notification.body);
              _seenNotificationIds.add(notification.id);
            }
          }
        } else {
          // Record existing notification IDs so we don't alert for them
          for (final n in data) {
            _seenNotificationIds.add(n.id);
          }
          _isFirstLoad = false;
        }
        _notifications = data;
        notifyListeners();
      });
      _setupPushNotifications(userId);
    } else {
      notifyListeners();
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> data = const {},
  }) async {
    final notification = NotificationModel(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      body: body,
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );
    await _notificationService.sendNotification(notification);
  }

  Future<void> markAsRead(String notificationId) async {
    if (_userId == null) return;
    await _notificationService.markAsRead(_userId!, notificationId);
  }

  Future<void> deleteNotification(String notificationId) async {
    if (_userId == null) return;
    await _notificationService.deleteNotification(_userId!, notificationId);
  }

  Future<void> acceptFriendRequest(String notificationId, String requesterId) async {
    if (_userId == null) return;
    
    // 1. Update current user's friends list (allowed)
    final currentUser = await _userService.getUserProfile(_userId!);
    if (currentUser != null) {
      final updatedFriends = List<String>.from(currentUser.friends);
      if (!updatedFriends.contains(requesterId)) {
        updatedFriends.add(requesterId);
      }
      
      await _userService.updateUserProfile(_userId!, {
        'friends': updatedFriends,
      });
      
      // 2. Send 'Acceptance' notification back to requester
      await sendNotification(
        userId: requesterId,
        title: 'Friend Request Accepted',
        body: '${currentUser.name} accepted your friend request!',
        type: 'friend_accepted',
        data: {'friendId': _userId},
      );
    }

    await deleteNotification(notificationId);
  }

  Future<void> handleFriendAccepted(String friendId) async {
    if (_userId == null) return;
    
    // Update current user's friends list (allowed)
    final currentUser = await _userService.getUserProfile(_userId!);
    if (currentUser != null) {
      final updatedFriends = List<String>.from(currentUser.friends);
      if (!updatedFriends.contains(friendId)) {
        updatedFriends.add(friendId);
      }
      
      await _userService.updateUserProfile(_userId!, {
        'friends': updatedFriends,
        'sentFriendRequests': FieldValue.arrayRemove([friendId]),
      });
    }
  }

  Future<void> declineFriendRequest(String notificationId, String requesterId) async {
    if (_userId == null) return;
    final currentUser = await _userService.getUserProfile(_userId!);
    if (currentUser != null) {
      final updatedRequests = List<String>.from(currentUser.friendRequests)
        ..remove(requesterId);
      await _userService.updateUserProfile(_userId!, {
        'friendRequests': updatedRequests,
      });
    }
    await deleteNotification(notificationId);
  }

  Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (!kIsWeb) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> _setupPushNotifications(String userId) async {
    // 1. Request permissions (now more robust)
    await requestPermission();

    // 2. Get FCM token
    String? token = await _messaging.getToken();
    if (token != null) {
      await _notificationService.updateFcmToken(userId, token);
    }

    // 3. Setup local notifications for foreground (Non-Web only)
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await (_localNotifications as dynamic).initialize(initializationSettings);
    }

      // 4. Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kIsWeb) return; // Local notifications not supported on web
        
        RemoteNotification? notification = message.notification;
        if (notification != null) {
          (_localNotifications as dynamic).show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );
        }
      });
    }
  
  Future<void> _showLocalNotification(String title, String body) async {
    if (kIsWeb) return;
    
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await (_localNotifications as dynamic).show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
