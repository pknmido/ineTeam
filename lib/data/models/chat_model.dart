import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String creatorId;
  final List<String> participantIds;
  final bool isGroup;
  final String? groupName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, DateTime> lastReadAt;

  const ChatModel({
    required this.id,
    required this.creatorId,
    required this.participantIds,
    this.isGroup = false,
    this.groupName,
    required this.lastMessage,
    required this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.lastReadAt = const {},
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    final rawLastReadAt = map['lastReadAt'];
    Map<String, DateTime> lastReadAt = {};
    if (rawLastReadAt is Map) {
      lastReadAt = rawLastReadAt.map((k, v) => MapEntry(
            k.toString(),
            (v as Timestamp).toDate(),
          ));
    }
    return ChatModel(
      id: id,
      creatorId: map['creatorId'] ?? '',
      participantIds: List<String>.from(map['participantIds'] ?? []),
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      lastReadAt: lastReadAt,
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
      'lastMessageSenderId': lastMessageSenderId,
      'lastReadAt': lastReadAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
    };
  }

  ChatModel copyWith({
    String? id,
    String? creatorId,
    List<String>? participantIds,
    bool? isGroup,
    String? groupName,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    Map<String, DateTime>? lastReadAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      participantIds: participantIds ?? this.participantIds,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
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
