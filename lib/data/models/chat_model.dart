import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String creatorId;
  final List<String> participantIds;
  final bool isGroup;
  final String? groupName;
  final String lastMessage;
  final DateTime lastMessageTime;

  const ChatModel({
    required this.id,
    required this.creatorId,
    required this.participantIds,
    this.isGroup = false,
    this.groupName,
    required this.lastMessage,
    required this.lastMessageTime,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      id: id,
      creatorId: map['creatorId'] ?? '',
      participantIds: List<String>.from(map['participantIds'] ?? []),
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'participantIds': participantIds,
      'isGroup': isGroup,
      'groupName': groupName,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
    };
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
