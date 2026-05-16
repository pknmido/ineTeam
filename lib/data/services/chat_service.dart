import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
          final chats = snap.docs.map((doc) => ChatModel.fromMap(doc.data(), doc.id)).toList();
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return chats;
        });
  }

  Stream<List<MessageModel>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => MessageModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<ChatModel> createOrGetChat(List<String> participantIds, {bool isGroup = false, String? groupName}) async {
    String chatId;
    final currentUserId = _auth.currentUser?.uid ?? participantIds[0];
    
    if (!isGroup && participantIds.length == 2) {
      final sortedIds = List<String>.from(participantIds)..sort();
      chatId = sortedIds.join('_');
      
      try {
        final doc = await _firestore.collection('chats').doc(chatId).get();
        if (doc.exists) {
          return ChatModel.fromMap(doc.data()!, doc.id);
        }
      } catch (e) {
        // If get() fails due to permissions, it might mean the doc exists but we aren't in participantIds
        // OR it's just a permission issue on the collection.
        debugPrint('Error getting chat doc: $e');
      }
    } else {
      chatId = _firestore.collection('chats').doc().id;
    }

    final newChat = ChatModel(
      id: chatId,
      creatorId: currentUserId,
      participantIds: participantIds,
      isGroup: isGroup,
      groupName: groupName,
      lastMessage: '',
      lastMessageTime: DateTime.now(),
    );

    try {
      await _firestore.collection('chats').doc(chatId).set(newChat.toMap());
      return newChat;
    } catch (e) {
      debugPrint('Error creating chat: $e');
      rethrow;
    }
  }

  Future<void> addMembers(String chatId, List<String> userIds) async {
    await _firestore.collection('chats').doc(chatId).update({
      'participantIds': FieldValue.arrayUnion(userIds),
    });
  }

  Future<void> removeMember(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'participantIds': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> leaveGroup(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'participantIds': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> deleteGroup(String chatId) async {
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    
    // Delete messages sub-collection (NOTE: In production with many messages, 
    // you should use a Cloud Function or recursive deletion. 
    // For now, we'll just delete the chat doc as rules handle sub-collections).
    batch.delete(chatRef);
    await batch.commit();
  }

  Future<void> sendMessage(String chatId, String senderId, String text) async {
    // 1. Get chat info to know recipients
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return;
    final chat = ChatModel.fromMap(chatDoc.data()!, chatId);

    // 2. Get sender info for notification body
    final senderDoc = await _firestore.collection('users').doc(senderId).get();
    final senderName = senderDoc.exists ? (senderDoc.data()?['name'] ?? 'Someone') : 'Someone';

    final message = MessageModel(
      id: '',
      chatId: chatId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    );

    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();
    
    batch.set(msgRef, message.toMap());
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageTime': Timestamp.fromDate(message.timestamp),
    });

    await batch.commit();

    // 3. Send notifications to all participants except sender
    final notificationService = NotificationService();
    for (final recipientId in chat.participantIds) {
      if (recipientId == senderId) continue;

      await notificationService.sendNotification(NotificationModel(
        id: const Uuid().v4(),
        userId: recipientId,
        title: chat.isGroup ? (chat.groupName ?? 'Group Message') : 'New Message',
        body: chat.isGroup ? '$senderName: $text' : '$senderName: $text',
        type: 'chat_message',
        createdAt: DateTime.now(),
        data: {'chatId': chatId},
      ));
    }
  }
}
