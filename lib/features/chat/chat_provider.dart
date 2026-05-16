import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/chat_model.dart';
import '../../data/services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  String? _userId;

  List<ChatModel> _chats = [];
  StreamSubscription? _chatsSub;

  List<ChatModel> get chats => _chats;

  void initialize(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _chatsSub?.cancel();
    if (userId != null) {
      _chatsSub = _chatService.getUserChats(userId).listen((data) {
        _chats = data;
        notifyListeners();
      });
    } else {
      _chats = [];
      notifyListeners();
    }
  }

  Future<ChatModel> getOrCreateDirectChat(String otherUserId) async {
    if (_userId == null) throw Exception('Not logged in');
    return await _chatService.createOrGetChat([_userId!, otherUserId]);
  }

  Future<ChatModel> createGroupChat(String name, List<String> memberIds) async {
    if (_userId == null) throw Exception('Not logged in');
    final allIds = [_userId!, ...memberIds].toSet().toList();
    return await _chatService.createOrGetChat(allIds, isGroup: true, groupName: name);
  }

  Future<void> sendMessage(String chatId, String text) async {
    if (_userId == null) return;
    await _chatService.sendMessage(chatId, _userId!, text);
  }

  Stream<List<MessageModel>> getChatMessages(String chatId) {
    return _chatService.getChatMessages(chatId);
  }

  @override
  void dispose() {
    _chatsSub?.cancel();
    super.dispose();
  }
}
