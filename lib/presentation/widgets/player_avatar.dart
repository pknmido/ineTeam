import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/helpers.dart';

/// Circular player avatar with fallback initials and optional skill ring.
/// Supports emoji avatars stored as 'emoji:⚽' in profilePictureUrl.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final int? skillLevel;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.skillLevel,
  });

  @override
  Widget build(BuildContext context) {
    final initials = Helpers.getInitials(name);
    final isEmoji = imageUrl != null && imageUrl!.startsWith('emoji:');
    final emojiChar = isEmoji ? imageUrl!.substring(6) : null;
    final hasNetworkImage =
        imageUrl != null && imageUrl!.isNotEmpty && !isEmoji;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor:
          Theme.of(context).colorScheme.primary.withAlpha(40),
      child: isEmoji
          ? Text(
              emojiChar!,
              style: TextStyle(fontSize: radius * 0.9),
            )
          : hasNetworkImage
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: radius * 0.6,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Text(
                      initials,
                      style: TextStyle(
                        fontSize: radius * 0.6,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                )
              : Text(
                  initials,
                  style: TextStyle(
                    fontSize: radius * 0.6,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
    );

    // Add skill ring if provided
    if (skillLevel != null) {
      final ringColor = Helpers.skillColor(skillLevel!);
      avatar = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ringColor, width: 2),
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
