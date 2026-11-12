import 'package:flutter/material.dart';
import '../services/user_service.dart';

/// Tüm rakip / oyuncu gösterimleri için ortak kullanıcı kartı şablonu.
///
/// Gerçek oyuncu ve bot ayrımı UI katmanına taşınmaz: bu widget yalnızca
/// avatar, çerçeve, isim ve opsiyonel alt satır (ör. ünvan) bilgisini çizer.
enum UserCardSize { dense, regular, large }

class UserCard extends StatelessWidget {
  final String avatarIndex;
  final String frameId;
  final String name;
  final String? subtitle;
  final UserCardSize size;
  final bool showFrameRing;
  final bool showOnlineDot;
  final Color accentColor;
  final Color nameColor;
  final CrossAxisAlignment alignment;
  final Widget? badge;

  const UserCard({
    super.key,
    required this.avatarIndex,
    required this.name,
    this.frameId = '0',
    this.subtitle,
    this.size = UserCardSize.regular,
    this.showFrameRing = false,
    this.showOnlineDot = false,
    this.accentColor = const Color(0xFF6366F1),
    this.nameColor = Colors.white,
    this.alignment = CrossAxisAlignment.center,
    this.badge,
  });

  double get _avatarRadius {
    switch (size) {
      case UserCardSize.dense:
        return 12;
      case UserCardSize.regular:
        return 26;
      case UserCardSize.large:
        return 30;
    }
  }

  double get _nameSize {
    switch (size) {
      case UserCardSize.dense:
        return 10.5;
      case UserCardSize.regular:
        return 13;
      case UserCardSize.large:
        return 14;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = UserService.hasAvatar(avatarIndex);
    final avatar = CircleAvatar(
      radius: _avatarRadius,
      backgroundColor: const Color(0xFF1E293B),
      backgroundImage: hasAvatar
          ? ResizeImage(
              AssetImage(UserService.getAvatarPath(avatarIndex)),
              width: (_avatarRadius * 4).round(),
              height: (_avatarRadius * 4).round(),
            )
          : null,
      child: hasAvatar
          ? null
          : Icon(Icons.person_rounded,
              size: _avatarRadius, color: Colors.white70),
    );

    final Widget avatarBlock = showFrameRing || showOnlineDot || badge != null
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: showFrameRing
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: UserService.getFrameColor(frameId),
                          width: 3,
                        ),
                      )
                    : null,
                child: avatar,
              ),
              if (badge != null)
                Positioned(top: -4, right: -4, child: badge!),
              if (showOnlineDot)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E293B), width: 2),
                    ),
                  ),
                ),
            ],
          )
        : avatar;

    final textAlign = alignment == CrossAxisAlignment.start
        ? TextAlign.start
        : TextAlign.center;

    final nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        color: nameColor,
        fontWeight: FontWeight.w800,
        fontSize: _nameSize,
      ),
    );

    if (size == UserCardSize.dense) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatarBlock,
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                nameText,
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        avatarBlock,
        const SizedBox(height: 8),
        nameText,
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: const TextStyle(
                color: Color(0xFFFFD56B),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
