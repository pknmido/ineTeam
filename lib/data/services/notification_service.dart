import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/notification_model.dart';

/// NotificationService handles the delivery and management of notifications.
///
/// It uses Firebase Cloud Functions (v2) to securely route push notifications
/// via the FCM HTTP v1 API, ensuring no sensitive keys are stored on the device.
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Fetches a real-time stream of notifications for a specific user.
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Sends a notification by writing to Firestore and triggering a secure Cloud Function.
  Future<void> sendNotification(NotificationModel notification) async {
    // 1. Store the notification in Firestore for the in-app notification center.
    // This allows the user to see their history even if they miss the push notification.
    await _firestore
        .collection('users')
        .doc(notification.userId)
        .collection('notifications')
        .doc(notification.id)
        .set(notification.toMap());

    // 2. Fetch the recipient's FCM token to target their specific device.
    final userDoc = await _firestore.collection('users').doc(notification.userId).get();
    final fcmToken = userDoc.data()?['fcmToken'];

    if (fcmToken != null) {
      // 3. Trigger the secure Cloud Function to handle the actual delivery.
      await sendPushNotification(
        targetToken: fcmToken,
        title: notification.title,
        body: notification.body,
        data: {
          'type': notification.type,
          'notificationId': notification.id,
          ...notification.data,
        },
      );
    }
  }

  /// Calls the 'sendPushNotification' Cloud Function securely.
  /// No Server Keys or secrets are used here; the Function handles authentication via the Admin SDK.
  Future<void> sendPushNotification({
    required String targetToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('sendPushNotification');
      
      final results = await callable.call(<String, dynamic>{
        'targetToken': targetToken,
        'title': title,
        'body': body,
        'data': data ?? {},
      });

      print('Cloud Function success: ${results.data}');
    } on FirebaseFunctionsException catch (e) {
      print('Cloud Function error: [${e.code}] ${e.message}');
    } catch (e) {
      print('Unexpected error calling Cloud Function: $e');
    }
  }

  /// Marks a specific notification as read in Firestore.
  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Permanently deletes a notification from the user's history.
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  /// Updates the current user's FCM token in Firestore for targeted delivery.
  Future<void> updateFcmToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }
}
