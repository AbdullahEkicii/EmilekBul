import '../services/behavior_tracker.dart';
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'glass_alert_dialog.dart';

import '../constants/app_categories.dart';
import '../models/duel_room_model.dart';
import '../screens/duel_room_screen.dart';
import '../services/analytics_service.dart';
import '../services/duel_service.dart';
import '../services/duel_ticket_service.dart';
import '../services/token_service.dart';
import '../services/user_service.dart';
import '../utils/app_utils.dart';

/// Tek dokunuşla eşleşme: bekleyen bir Hızlı Maç odasına katılır, yoksa kendi
/// Hızlı Maç odasını açar (bot birkaç saniye içinde katılır). Bahis: bilet varsa 10, yoksa dostluk maçı.
class QuickMatchDialog extends StatefulWidget {
  const QuickMatchDialog({super.key});

  static Future<void> show(BuildContext context) {
    BehaviorTracker.track('quick_match');
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const QuickMatchDialog(),
    );
  }

  @override
  State<QuickMatchDialog> createState() => _QuickMatchDialogState();
}

class _QuickMatchDialogState extends State<QuickMatchDialog> {
  static const Duration _joinApprovalTimeout = Duration(seconds: 8);

  bool _cancelled = false;
  String? _pendingRoomCode;
  StreamSubscription<DuelRoom?>? _roomSub;
  Timer? _tickTimer;
  final Stopwatch _elapsed = Stopwatch()..start();
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    // Geçen süreyi göstererek bekleme hissini netleştir
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds = _elapsed.elapsed.inSeconds);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<DuelPlayer?> _currentPlayer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final lang = context.locale.languageCode;
    final data = await UserService.getUserProfile(user.uid);
    final tokens = await TokenService.getTokenAmount();
    return DuelPlayer(
      uid: user.uid,
      username: data?['username']?.toString() ?? 'Oyuncu',
      avatarIndex: data?['avatarIndex']?.toString() ?? '1',
      equippedFrame: data?['equippedFrame']?.toString() ?? '0',
      equippedTitle: data?['equippedTitle']?.toString() ?? 'yok',
      tokens: tokens,
      language: lang,
    );
  }

  Future<void> _run() async {
    AnalyticsService.logDuelFunnel('quick_match_tap');
    if (!await AppUtils.hasInternetConnection()) {
      _fail('errors.no_internet_ai'.tr());
      return;
    }

    final player = await _currentPlayer();
    if (player == null || _cancelled) {
      _close();
      return;
    }
    final bet = await DuelTicketService.ticketsLeft() > 0 ? DuelTicketService.maxTicketBet : 0;

    // 1) Bekleyen bir Hızlı Maç odası var mı?
    final joined = await _tryJoinWaitingRoom(player, bet);
    if (joined || _cancelled) return;

    // 2) Yoksa kendi Hızlı Maç odasını aç
    try {
      final categories = AppCategories.categories;
      final category = categories[Random().nextInt(categories.length)].name;
      final roomCode = await DuelService.createRoom(
        hostPlayer: player,
        config: DuelConfig(category: category, difficulty: 'Orta', questionCount: 5, betTokens: bet),
      );
      await FirebaseFirestore.instance.collection('duel_rooms').doc(roomCode).update({'quickMatch': true});
      if (_cancelled) {
        DuelService.leaveRoom(roomCode, isHost: true, uid: player.uid);
        return;
      }
      AnalyticsService.logDuelFunnel('quick_match_created', parameters: {'bet': bet});
      _openRoom(roomCode, isHost: true);
    } catch (e) {
      debugPrint('Quick match create error: $e');
      _fail('duel.create_room_error'.tr());
    }
  }

  Future<bool> _tryJoinWaitingRoom(DuelPlayer player, int bet) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('duel_rooms')
          .where('quickMatch', isEqualTo: true)
          .where('status', isEqualTo: 'waiting')
          .limit(10)
          .get();
      final now = DateTime.now();
      final candidates = snap.docs.map((d) => (DuelRoom.fromMap(d.data(), d.id), d.data())).where((pair) {
        final room = pair.$1;
        final lastActivity = pair.$2['lastActivity'];
        final fresh = lastActivity is Timestamp && now.difference(lastActivity.toDate()).inSeconds < 60;
        return fresh &&
            room.hostUid != player.uid &&
            !room.hostUid.startsWith('bot_') &&
            room.guest == null &&
            room.pendingGuest == null &&
            room.config.betTokens == bet;
      }).toList();
      if (candidates.isEmpty || _cancelled) return false;

      final roomCode = candidates.first.$1.roomCode;
      final result = await DuelService.requestJoinRoom(roomCode: roomCode, guestPlayer: player);
      if (result['success'] != true || _cancelled) return false;
      if (result['isDirect'] == true) {
        _openRoom(roomCode, isHost: false);
        return true;
      }

      // Karşı taraf Hızlı Maç lobisinde isteği otomatik onaylar
      _pendingRoomCode = roomCode;
      final approved = Completer<bool>();
      _roomSub = DuelService.streamRoom(roomCode).listen((room) {
        if (approved.isCompleted) return;
        if (room == null || room.status == 'closed') {
          approved.complete(false);
        } else if (room.guest?.uid == player.uid) {
          approved.complete(true);
        }
      });
      final ok = await approved.future.timeout(_joinApprovalTimeout, onTimeout: () => false);
      await _roomSub?.cancel();
      _roomSub = null;
      if (!ok) {
        DuelService.cancelJoinRequest(roomCode, player.uid);
        _pendingRoomCode = null;
        return false;
      }
      if (_cancelled) return true;
      AnalyticsService.logDuelFunnel('quick_match_joined', parameters: {'bet': bet});
      _openRoom(roomCode, isHost: false);
      return true;
    } catch (e) {
      debugPrint('Quick match join error: $e');
      return false;
    }
  }

  Future<void> _openRoom(String roomCode, {required bool isHost}) async {
    // Çok hızlı eşleşmede diyalog yanıp sönmesin: en az ~1.2 sn göster
    final remaining = const Duration(milliseconds: 1200) - _elapsed.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
    if (!mounted || _cancelled) {
      if (_cancelled && isHost) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) DuelService.leaveRoom(roomCode, isHost: true, uid: uid);
      }
      return;
    }
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => DuelRoomScreen(roomCode: roomCode, isHost: isHost, quickMatch: true),
      ),
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  void _cancel() {
    _cancelled = true;
    AnalyticsService.logDuelFunnel('quick_match_cancel');
    final pending = _pendingRoomCode;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (pending != null && uid != null) DuelService.cancelJoinRequest(pending, uid);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return GlassAlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox.expand(
                  child: CircularProgressIndicator(color: Color(0xFFFF9F43), strokeWidth: 4),
                ),
                Text(
                  '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'duel.quick_match_searching'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'duel.quick_match_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
