import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatModel.fromMap(doc.data(), doc.id)).toList());
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
    if (!isGroup && participantIds.length == 2) {
      // Check if a direct chat already exists
      final query = await _firestore
          .collection('chats')
          .where('participantIds', arrayContains: participantIds[0])
          .get();
      
      for (var doc in query.docs) {
        final chat = ChatModel.fromMap(doc.data(), doc.id);
        if (!chat.isGroup && chat.participantIds.contains(participantIds[1])) {
          return chat;
        }
      }
    }

    final newChatRef = _firestore.collection('chats').doc();
    final newChat = ChatModel(
      id: newChatRef.id,
      participantIds: participantIds,
      isGroup: isGroup,
      groupName: groupName,
      lastMessage: '',
      lastMessageTime: DateTime.now(),
    );

    await newChatRef.set(newChat.toMap());
    return newChat;
  }

  Future<void> sendMessage(String chatId, String senderId, String text) async {
    final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc();
    final message = MessageModel(
      id: messageRef.id,
      chatId: chatId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    );

    await _firestore.runTransaction((transaction) async {
      final chatRef = _firestore.collection('chats').doc(chatId);
      transaction.set(messageRef, message.toMap());
      transaction.update(chatRef, {
        'lastMessage': text,
        'lastMessageTime': Timestamp.fromDate(message.timestamp),
      });
    });
  }
}
