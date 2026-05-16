import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../features/notifications/notification_provider.dart';
import '../../../core/utils/helpers.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications = notificationProvider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: notifications.isEmpty
          ? const Center(child: Text('No notifications right now.'))
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isUnread = !notification.isRead;

                return ListTile(
                  tileColor: isUnread ? Theme.of(context).colorScheme.primary.withAlpha(20) : null,
                  leading: Icon(
                    _getIconForType(notification.type),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                  ),
                  subtitle: Text(notification.body),
                  trailing: _getTrailingForType(context, notification, notificationProvider),
                  onTap: () {
                    if (isUnread) {
                      notificationProvider.markAsRead(notification.id);
                    }
                    if (notification.type == 'chat_message') {
                      final chatId = notification.data['chatId'];
                      if (chatId != null) {
                        context.push('/chat/$chatId');
                      }
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _getTrailingForType(BuildContext context, dynamic notification, NotificationProvider provider) {
    if (notification.type == 'friend_request') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () => provider.acceptFriendRequest(notification.id, notification.data['requesterId']),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => provider.declineFriendRequest(notification.id, notification.data['requesterId']),
          ),
        ],
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => provider.deleteNotification(notification.id),
      );
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'friend_accepted':
        return Icons.person_add_alt_1;
      case 'match_deleted':
        return Icons.cancel_outlined;
      case 'match_reminder':
        return Icons.timer;
      case 'chat_message':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications;
    }
  }
}
