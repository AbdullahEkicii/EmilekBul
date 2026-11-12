import '../services/behavior_tracker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/league_service.dart';
import '../services/user_service.dart';
import '../utils/app_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/my_native_ad.dart';
import '../widgets/navigation_buttons.dart';

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  League _league = LeagueService.leagues.first;
  List<LeagueEntry> _entries = [];
  int _participants = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    BehaviorTracker.track('league');
  }

  Future<void> _load() async {
    try {
      final league = await LeagueService.getMyLeague();
      final results = await Future.wait([
        LeagueService.getLeaderboard(league),
        LeagueService.getParticipantCount(league),
      ]);
      if (!mounted) return;
      setState(() {
        _league = league;
        _entries = results[0] as List<LeagueEntry>;
        _participants = results[1] as int;
        _loading = false;
      });
    } catch (e) {
      debugPrint('LeagueScreen load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _zoneSize => (_participants * LeagueService.zoneRatio).ceil().clamp(1, _participants < 1 ? 1 : _participants);

  bool _isPromotionRank(int rank) =>
      _league != LeagueService.leagues.last && rank <= _zoneSize;

  bool _isDemotionRank(int rank) =>
      _league != LeagueService.leagues.first &&
      _participants >= LeagueService.minPlayersForDemotion &&
      rank > _participants - _zoneSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 10),
                  Text(
                    'league.title'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        children: [
                          _buildHeaderCard(),
                          const SizedBox(height: 16),
                          if (_entries.isEmpty) _buildEmpty() else ..._buildRows(),
                        ],
                      ),
                    ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: MyNativeAd(height: 65),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final left = LeagueService.timeLeftInWeek();
    final daysLeft = left.inDays;
    final hoursLeft = left.inHours % 24;

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: LeagueService.leagues.map((l) {
              final isCurrent = l == _league;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: isCurrent ? 1 : 0.35,
                  child: Container(
                    width: isCurrent ? 56 : 40,
                    height: isCurrent ? 56 : 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: l.color.withValues(alpha: 0.15),
                      border: Border.all(color: l.color.withValues(alpha: isCurrent ? 0.9 : 0.4), width: isCurrent ? 2 : 1),
                    ),
                    child: Text(l.emoji, style: TextStyle(fontSize: isCurrent ? 28 : 18)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            _league.titleKey.tr(),
            style: TextStyle(color: _league.color, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'league.ends_in'.tr(args: [daysLeft.toString(), hoursLeft.toString()]),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            'league.how_it_works'.tr(args: [(LeagueService.zoneRatio * 100).round().toString()]),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Text('🏁', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            'league.empty'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRows() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return List.generate(_entries.length, (i) {
      final entry = _entries[i];
      final rank = i + 1;
      final isMe = entry.uid == myUid;
      final promo = _isPromotionRank(rank);
      final demo = _isDemotionRank(rank);
      final zoneColor = promo
          ? const Color(0xFF22C55E)
          : demo
              ? const Color(0xFFEF4444)
              : Colors.white24;
      final hasAvatar = UserService.hasAvatar(entry.avatarIndex);

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _league.color.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? _league.color.withValues(alpha: 0.7) : Colors.white12),
        ),
        child: Row(
          children: [
            Container(width: 4, height: 32, decoration: BoxDecoration(color: zoneColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1E293B),
              backgroundImage: hasAvatar
                  ? ResizeImage(AssetImage(UserService.getAvatarPath(entry.avatarIndex)), width: 72, height: 72)
                  : null,
              child: hasAvatar ? null : const Icon(Icons.person_rounded, size: 18, color: Colors.white70),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppUtils.localizeUsername(entry.username),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              '${entry.weeklyPoints} ${'league.points'.tr()}',
              style: TextStyle(color: _league.color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    });
  }
}
