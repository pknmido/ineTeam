import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/notification_model.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/user_service.dart';
import 'package:uuid/uuid.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();
  final Uuid _uuid = const Uuid();

  List<NotificationModel> _notifications = [];
  StreamSubscription? _sub;
  String? _userId;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void initialize(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _sub?.cancel();
    if (userId != null) {
      _sub = _notificationService.getUserNotifications(userId).listen((data) {
        _notifications = data;
        notifyListeners();
      });
    } else {
      _notifications = [];
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
    // Add requesterId to friends list of current user
    // Add current user to friends list of requesterId
    // Remove requesterId from friendRequests of current user
    
    // Simple approach: we need a user provider or service call
    final currentUser = await _userService.getUserProfile(_userId!);
    if (currentUser != null) {
      final updatedFriends = List<String>.from(currentUser.friends);
      if (!updatedFriends.contains(requesterId)) {
        updatedFriends.add(requesterId);
      }
      final updatedRequests = List<String>.from(currentUser.friendRequests)
        ..remove(requesterId);

      await _userService.updateUserProfile(_userId!, {
        'friends': updatedFriends,
        'friendRequests': updatedRequests,
      });
      
      // Update the other user
      final otherUser = await _userService.getUserProfile(requesterId);
      if (otherUser != null) {
        final otherFriends = List<String>.from(otherUser.friends);
        if (!otherFriends.contains(_userId!)) {
          otherFriends.add(_userId!);
        }
        await _userService.updateUserProfile(requesterId, {
          'friends': otherFriends,
        });
      }
    }

    await deleteNotification(notificationId);
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
