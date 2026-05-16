import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                  trailing: notification.type == 'friend_request'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                notificationProvider.acceptFriendRequest(
                                  notification.id,
                                  notification.data['requesterId'],
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                notificationProvider.declineFriendRequest(
                                  notification.id,
                                  notification.data['requesterId'],
                                );
                              },
                            ),
                          ],
                        )
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => notificationProvider.deleteNotification(notification.id),
                        ),
                  onTap: () {
                    if (isUnread) {
                      notificationProvider.markAsRead(notification.id);
                    }
                  },
                );
              },
            ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'match_deleted':
        return Icons.cancel_outlined;
      case 'match_reminder':
        return Icons.timer;
      default:
        return Icons.notifications;
    }
  }
}
