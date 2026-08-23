import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/duel_room_model.dart';
import '../constants/app_categories.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/achievement_service.dart';
import '../services/duel_service.dart';
import '../services/token_service.dart';
import '../services/user_service.dart';
import '../services/friend_service.dart';
import '../models/friend_model.dart';
import '../utils/app_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/token_widget.dart';
import '../widgets/my_native_ad.dart';
import 'duel_room_screen.dart';

class LiveDuelResultScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;
  final DuelRoom? initialRoom;

  const LiveDuelResultScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
    this.initialRoom,
  });

  @override
  State<LiveDuelResultScreen> createState() => _LiveDuelResultScreenState();
}

class _LiveDuelResultScreenState extends State<LiveDuelResultScreen> {
  late StreamSubscription<DuelRoom?> _roomSubscription;
  DuelRoom? _room;
  bool _rewardAwarded = false;
  int _earnedLeaderboardPoints = 0;
  int _myCorrectCount = 0;
  Timer? _autoReturnTimer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    if (_room != null) {
      final initialWinner = _getEffectiveWinnerUid(_room!);
      if (initialWinner != null) {
        _handleRewardDistribution(_room!, initialWinner);
      }
    }
    _listenToRoom();
    _startAutoReturnTimer();
  }

  void _startAutoReturnTimer() {
    _autoReturnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _handleRematch();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  String? _getEffectiveWinnerUid(DuelRoom room) {
    if (room.winnerUid != null && room.winnerUid!.isNotEmpty) {
      return room.winnerUid;
    }
    final host = room.host;
    final guest = room.guest;
    if (guest == null) return host.uid;

    final hostScore = host.score;
    final guestScore = guest.score;
    final hostTime = host.finishTime;
    final guestTime = guest.finishTime;

    if (hostScore > guestScore) {
      return host.uid;
    } else if (guestScore > hostScore) {
      return guest.uid;
    } else {
      if (hostTime > 0 && guestTime > 0) {
        if (hostTime < guestTime) {
          return host.uid;
        } else if (guestTime < hostTime) {
          return guest.uid;
        } else {
          return 'tie';
        }
      } else if (hostTime > 0 && guestTime == 0) {
        return host.uid;
      } else if (guestTime > 0 && hostTime == 0) {
        return guest.uid;
      }
      return null;
    }
  }

  void _listenToRoom() {
    _roomSubscription = DuelService.streamRoom(widget.roomCode).listen((room) {
      if (!mounted || room == null) return;

      setState(() {
        _room = room;
      });

      final effectiveWinner = _getEffectiveWinnerUid(room);
      // Distribute prize and calculate leaderboard points once
      if (!_rewardAwarded && effectiveWinner != null) {
        _handleRewardDistribution(room, effectiveWinner);
      }
    });
  }

  void _navigateToLobby() {
    _autoReturnTimer?.cancel();
    _roomSubscription.cancel();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DuelRoomScreen(
          roomCode: widget.roomCode,
          isHost: widget.isHost,
        ),
      ),
    );
  }

  Future<void> _handleRewardDistribution(DuelRoom room, String effectiveWinnerUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _rewardAwarded = true;
    final bool isWinner = effectiveWinnerUid == user.uid;
    final bool isTie = effectiveWinnerUid == 'tie';

    // 1. Token Ödül Dağıtımı
    if (isWinner) {
      final prize = room.prizeTokens;
      await TokenService.addTokens(prize);
    } else if (isTie) {
      // Refund bet tokens
      await TokenService.addTokens(room.config.betTokens);
    }

    // 2. Genel & Aylık Puanlama ve Sıralama Entegrasyonu
    final bool isHost = widget.isHost;
    final myPlayer = isHost ? room.host : (room.guest ?? room.host);

    int correctCount = 0;
    for (int i = 0; i < room.questions.length; i++) {
      if (i < myPlayer.userAnswers.length && myPlayer.userAnswers[i] == room.questions[i].correctIndex) {
        correctCount++;
      }
    }

    final katsayilar = {
      'Kolay': 2,
      'Orta': 3,
      'Zor': 4,
      'Imkansız': 5,
      'Easy': 2,
      'Medium': 3,
      'Hard': 4,
      'Impossible': 5,
    };
    final int katsayi = katsayilar[room.config.difficulty] ?? 3;
    
    // Dengeli düello puanlama sistemi (Tekli testlerle orantılı: Orta 4 doğru = 12 + 6 galibiyet = 18 puan, max 21-25 puan)
    int basePuan = correctCount * katsayi;
    if (isWinner) {
      basePuan += (katsayi * 2); // Düello Galibiyet Bonusu (Orta için +6 puan)
    }
    if (AppCategories.isCategoryWeeklyBonus(room.config.category)) {
      basePuan *= 2;
    }
    final int totalPuan = basePuan;

    if (mounted) {
      setState(() {
        _earnedLeaderboardPoints = totalPuan;
        _myCorrectCount = correctCount;
      });
    }

    try {
      await UserService.addPointsToUser(
        uid: user.uid,
        category: room.config.category,
        pointsToAdd: totalPuan,
        difficulty: room.config.difficulty,
      );

      if (isWinner) {
        final prefs = await SharedPreferences.getInstance();
        final currentWins = (prefs.getInt('duel_wins_count') ?? 0) + 1;
        await prefs.setInt('duel_wins_count', currentWins);
        if (mounted) {
          await AchievementService.checkAndUnlockDuelAchievements(currentWins, context);
        }
      }
    } catch (e) {
      debugPrint('Error saving friend duel leaderboard points: $e');
    }
  }

  String _getLocalizedDifficulty(String diff) {
    switch (diff.toLowerCase()) {
      case 'kolay':
      case 'easy':
        return 'category_ui.difficulty.easy'.tr();
      case 'orta':
      case 'medium':
        return 'category_ui.difficulty.medium'.tr();
      case 'zor':
      case 'hard':
        return 'category_ui.difficulty.hard'.tr();
      case 'imkansız':
      case 'imkansiz':
      case 'impossible':
        return 'category_ui.difficulty.impossible'.tr();
      default:
        return diff;
    }
  }

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
    _roomSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleRematch() async {
    _autoReturnTimer?.cancel();
    await DuelService.returnToLobby(widget.roomCode, isHost: widget.isHost);
    _navigateToLobby();
  }

  Future<void> _handleExit() async {
    _autoReturnTimer?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await DuelService.leaveRoom(
        widget.roomCode,
        isHost: widget.isHost,
        uid: user.uid,
      );
    }
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF9F43)),
        ),
      );
    }

    final room = _room!;
    final user = FirebaseAuth.instance.currentUser;
    final myUid = user?.uid ?? '';
    final effectiveWinnerUid = _getEffectiveWinnerUid(room);
    final bool isWinner = effectiveWinnerUid != null && effectiveWinnerUid == myUid;
    final bool isTie = effectiveWinnerUid == 'tie';

    final betTokens = room.config.betTokens;
    final totalPot = betTokens * 2;
    final feeRate = DuelRoom.getCommissionRate(betTokens);
    final fee = (totalPot * feeRate).round();
    final prize = (room.prizeTokens > 0) ? room.prizeTokens : DuelRoom.calculatePrize(betTokens);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildWinnerBanner(effectiveWinnerUid: effectiveWinnerUid, myUid: myUid),
                        const SizedBox(height: 16),
                        _buildPointsEarnedCard(room: room, isWinner: isWinner),
                        const SizedBox(height: 16),
                        const MyNativeAd(
                          height: 70,
                          factoryId: 'adFactorySmall',
                        ),
                        const SizedBox(height: 16),
                        _buildPrizeBreakdownCard(
                          isWinner: isWinner,
                          isTie: isTie,
                          betTokens: betTokens,
                          totalPot: totalPot,
                          fee: fee,
                          prize: prize,
                        ),
                        const SizedBox(height: 16),
                        _buildPlayerComparisonCard(room, myUid),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildBottomButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'result.title'.tr(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const TokenWidget(),
        ],
      ),
    );
  }

  Widget _buildWinnerBanner({required String? effectiveWinnerUid, required String myUid}) {
    if (effectiveWinnerUid == null) {
      return GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        borderRadius: 24,
        opacity: 0.12,
        child: Column(
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: Color(0xFFFF9F43),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'duel.calculating_results'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFF9F43),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    final bool isWinner = effectiveWinnerUid == myUid;
    final bool isTie = effectiveWinnerUid == 'tie';

    String title;
    IconData icon;
    Color color;

    if (isWinner) {
      title = 'duel.won'.tr();
      icon = Icons.emoji_events_rounded;
      color = const Color(0xFFFFD56B);
    } else if (isTie) {
      title = 'duel.tie'.tr();
      icon = Icons.handshake_rounded;
      color = const Color(0xFF60A5FA);
    } else {
      title = 'duel.lost'.tr();
      icon = Icons.sentiment_dissatisfied_rounded;
      color = const Color(0xFFF87171);
    }

    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      borderRadius: 24,
      opacity: 0.12,
      child: Column(
        children: [
          Icon(icon, color: color, size: 54),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsEarnedCard({required DuelRoom room, required bool isWinner}) {
    final bool isWeekly = AppCategories.isCategoryWeeklyBonus(room.config.category);
    final katsayilar = {
      'Kolay': 2,
      'Orta': 3,
      'Zor': 4,
      'Imkansız': 5,
      'Easy': 2,
      'Medium': 3,
      'Hard': 4,
      'Impossible': 5,
    };
    final int katsayi = katsayilar[room.config.difficulty] ?? 3;

    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      opacity: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.leaderboard_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'duel.leaderboard_points'.tr(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      'duel.points_saved_to_profile'.tr(),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(
                  '+$_earnedLeaderboardPoints ${'welcome_screen.points'.tr()}',
                  style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBreakdownRow('duel.correct_answers'.tr(), '$_myCorrectCount / ${room.questions.length}'),
          const SizedBox(height: 6),
          () {
            final catKey = AppCategories.getCategoryKey(room.config.category);
            return _buildBreakdownRow('category_ui.preview_category'.tr(), catKey.isNotEmpty ? catKey.tr() : room.config.category);
          }(),
          const SizedBox(height: 6),
          _buildBreakdownRow('category_ui.preview_difficulty'.tr(), _getLocalizedDifficulty(room.config.difficulty)),
          if (isWinner) ...[
            const SizedBox(height: 6),
            _buildBreakdownRow('duel.winner_bonus'.tr(), '+${(katsayi * 2)} ${'welcome_screen.points'.tr()} 🔥', isHighlight: true),
          ],
          if (isWeekly) ...[
            const SizedBox(height: 6),
            _buildBreakdownRow('category_ui.weekly_bonus_badge'.tr(), '2X Bonus ⚡', isHighlight: true),
          ],
        ],
      ),
    );
  }

  Widget _buildPrizeBreakdownCard({
    required bool isWinner,
    required bool isTie,
    required int betTokens,
    required int totalPot,
    required int fee,
    required int prize,
  }) {
    final tokenUnit = 'token.unit'.tr();

    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      opacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'duel.prize_breakdown'.tr(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildBreakdownRow('duel.bet_amount'.tr(), '$betTokens $tokenUnit', isNegative: true),
          const SizedBox(height: 8),
          _buildBreakdownRow('duel.total_pot'.tr(), '$totalPot $tokenUnit'),
          const SizedBox(height: 8),
          _buildBreakdownRow('duel.fee_cut'.tr(), '-$fee $tokenUnit', isNegative: true),
          const Divider(color: Colors.white12, height: 20),

          // Net Award
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'duel.net_result'.tr(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                isWinner
                    ? '+$prize $tokenUnit 🔥'
                    : isTie
                        ? '$betTokens $tokenUnit (${'duel.refund'.tr()})'
                        : '-$betTokens $tokenUnit',
                style: TextStyle(
                  color: isWinner
                      ? const Color(0xFF10B981)
                      : isTie
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFFEF4444),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isNegative = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: isHighlight
                ? const Color(0xFFFFD56B)
                : (isNegative ? Colors.redAccent.shade100 : Colors.white),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerComparisonCard(DuelRoom room, String myUid) {
    final host = room.host;
    final guest = room.guest;

    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      opacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'duel.match_stats'.tr(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildPlayerStatItem(host, isWinner: room.winnerUid == host.uid)),
              Container(width: 1, height: 80, color: Colors.white12),
              Expanded(
                child: guest != null
                    ? _buildPlayerStatItem(guest, isWinner: room.winnerUid == guest.uid)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatItem(DuelPlayer player, {required bool isWinner}) {
    final seconds = (player.finishTime / 1000).toStringAsFixed(1);
    final localizedName = AppUtils.localizeUsername(player.username);

    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Builder(
              builder: (context) {
                final hasAvatar = UserService.hasAvatar(player.avatarIndex);
                return CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF1E293B),
                  backgroundImage: hasAvatar
                      ? ResizeImage(
                          AssetImage(UserService.getAvatarPath(player.avatarIndex)),
                          width: 104,
                          height: 104,
                        )
                      : null,
                  child: hasAvatar
                      ? null
                      : const Icon(Icons.person_rounded, size: 26, color: Colors.white70),
                );
              },
            ),
            if (isWinner)
              const Positioned(
                top: -4,
                right: -4,
                child: Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD56B), size: 20),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          localizedName,
          maxLines: 1,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          '${player.score} ${'welcome_screen.points'.tr()}',
          style: const TextStyle(color: Color(0xFFFFD56B), fontWeight: FontWeight.w900, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          '$seconds s',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
        ),
        _buildFriendActionButton(player.uid),
      ],
    );
  }

  Widget _buildFriendActionButton(String otherUid) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || otherUid.isEmpty || myUid == otherUid) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<FriendshipStatus>(
      stream: FriendService.streamFriendshipStatus(otherUid),
      builder: (context, snapshot) {
        final status = snapshot.data ?? FriendshipStatus.none;

        if (status == FriendshipStatus.friends) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 10),
                  const SizedBox(width: 3),
                  Text(
                    'friends.already_friends'.tr(),
                    style: const TextStyle(color: Colors.green, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        if (status == FriendshipStatus.sentPending) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 10),
                  const SizedBox(width: 3),
                  Text(
                    'friends.request_sent'.tr(),
                    style: const TextStyle(color: Colors.orange, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        if (status == FriendshipStatus.receivedPending) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: () async {
                HapticFeedback.lightImpact();
                final res = await FriendService.acceptRequestFrom(otherUid);
                final msgKey = res['message'] as String? ?? 'common.error';
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msgKey.tr()),
                      backgroundColor: res['success'] == true ? Colors.green : Colors.redAccent,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      'friends.accept_request'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              final res = await FriendService.sendFriendRequest(otherUid);
              final msgKey = res['message'] as String? ?? 'common.error';
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msgKey.tr()),
                    backgroundColor: res['success'] == true ? Colors.green : Colors.redAccent,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF6366F1), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_rounded, color: Color(0xFFA5B4FC), size: 10),
                  const SizedBox(width: 3),
                  Text(
                    'friends.add_friend'.tr(),
                    style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _handleExit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'duel.leave'.tr(),
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _handleRematch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F43),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.replay_rounded, color: Colors.black, size: 20),
                  Flexible(
                    child: Text(
                      '${'duel.return_to_room'.tr()} ($_secondsLeft s)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
