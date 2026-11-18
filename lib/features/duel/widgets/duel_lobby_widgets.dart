import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../models/duel_room_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';

class DuelRoomCodeCard extends StatelessWidget {
  final DuelRoom room;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  const DuelRoomCodeCard({
    super.key,
    required this.room,
    required this.onShare,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      opacity: 0.12,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF9F43), AppColors.coral]),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child:
                const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'duel.room_code'.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  room.roomCode,
                  style: const TextStyle(
                    color: Color(0xFFFFD56B),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFFFF9F43)),
            tooltip: 'duel.share_link'.tr(),
            onPressed: onShare,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white70),
            tooltip: 'duel.copy_code'.tr(),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class DuelEmptyGuestCard extends StatelessWidget {
  final int betTokens;

  const DuelEmptyGuestCard({
    super.key,
    required this.betTokens,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      opacity: 0.06,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white24, style: BorderStyle.solid),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: Colors.white38, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            'duel.waiting_guest'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DuelRoom.isSpecialHighBet(betTokens)
                ? 'duel.high_bet_real_only'.tr()
                : 'duel.share_code_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class DuelInsufficientTokensBanner extends StatelessWidget {
  final DuelRoom room;
  final int userTokens;

  const DuelInsufficientTokensBanner({
    super.key,
    required this.room,
    required this.userTokens,
  });

  @override
  Widget build(BuildContext context) {
    final bet = room.config.betTokens;
    final bool hostNeeds = userTokens < bet;
    final bool guestNeeds = room.guest != null && room.guest!.tokens < bet;

    final String msg;
    if (hostNeeds && guestNeeds) {
      msg = 'duel.both_need_tokens'.tr(args: [bet.toString()]);
    } else if (hostNeeds) {
      msg = 'duel.you_need_tokens'.tr(args: [bet.toString()]);
    } else {
      msg = 'duel.guest_needs_tokens'.tr(args: [bet.toString()]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
