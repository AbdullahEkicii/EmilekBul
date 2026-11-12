import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/glass_alert_dialog.dart';

import '../constants/app_categories.dart';
import '../models/category_model.dart';
import '../models/friend_model.dart';
import '../services/friend_service.dart';
import '../services/haptic_service.dart';
import '../services/tournament_service.dart';
import '../widgets/glass_container.dart';
import 'speed_round_screen.dart';

/// Arkadaş turnuvaları: kendi turnuvalarımın listesi, skor sıralaması, tur oynama ve oluşturma.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  Stream<List<Tournament>>? _stream;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid != null) _stream = TournamentService.streamMyTournaments(uid);
  }

  CategoryItem? _categoryFor(String name) {
    for (final c in AppCategories.categories) {
      if (c.name == name) return c;
    }
    return null;
  }

  String _remaining(DateTime endsAt) {
    final diff = endsAt.difference(DateTime.now());
    if (diff.isNegative) return '0h 0m';
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openCreate() async {
    final uid = _uid;
    if (uid == null || _busy) return;
    final request = await showDialog<_CreateRequest>(
      context: context,
      builder: (_) => _CreateTournamentDialog(uid: uid),
    );
    if (request == null || !mounted) return;

    setState(() => _busy = true);
    final result = await TournamentService.create(
      title: request.title,
      categoryName: request.categoryName,
      friends: request.friends,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(((result['message'] as String?) ?? 'common.error').tr());
  }

  Future<void> _play(Tournament t) async {
    if (_busy) return;
    final category = _categoryFor(t.category) ?? SpeedRoundScreen.weeklyCategory();
    HapticService.light();
    final score = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => SpeedRoundScreen(category: category, tournamentMode: true),
      ),
    );
    if (score == null || !mounted) return;

    setState(() => _busy = true);
    final ok = await TournamentService.submitScore(tournamentId: t.id, score: score);
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(ok
        ? 'tournament.score_saved'.tr(args: ['$score'])
        : 'tournament.score_failed'.tr());
  }

  Future<void> _finish(Tournament t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        content: Text('tournament.finish_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('tournament.finish'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await TournamentService.finish(t.id);
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(ok ? 'tournament.finished_ok'.tr() : 'common.error'.tr());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'tournament.title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
            tooltip: 'tournament.create'.tr(),
            onPressed: _uid == null ? null : _openCreate,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_uid == null || _stream == null) {
      return Center(
        child: Text(
          'auth.not_logged_in'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<List<Tournament>>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return Center(
                child: Text('common.error'.tr(), style: const TextStyle(color: Colors.white70)),
              );
            }
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'tournament.empty'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _busy ? null : _openCreate, child: Text('tournament.create'.tr())),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildCard(list[i]),
          );
        },
      ),
    );
  }

  Widget _buildCard(Tournament t) {
    final uid = _uid!;
    final category = _categoryFor(t.category);
    final color = category?.color ?? const Color(0xFF00D2D3);
    final isOwner = t.ownerUid == uid;
    final mine = t.participants[uid];
    final isOpen = t.isOpen;
    final ranking = t.ranking;

    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Text(
                isOpen ? 'tournament.status_open'.tr() : 'tournament.status_finished'.tr(),
                style: TextStyle(
                  color: isOpen ? const Color(0xFF96CEB4) : Colors.white54,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            category != null ? category.key.tr() : t.category,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (isOpen && t.endsAt != null) ...[
            const SizedBox(height: 2),
            Text(
              'tournament.ends_in'.tr(args: [_remaining(t.endsAt!)]),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < ranking.length; i++)
            _buildRankRow(i + 1, ranking[i], ranking[i].uid == uid),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isOpen && mine != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _play(t),
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text('tournament.play'.tr()),
                  ),
                ),
              if (isOpen && isOwner) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy ? null : () => _finish(t),
                  child: Text('tournament.finish'.tr()),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(int place, TournamentParticipant p, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$place',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              isMe ? '${p.username} (${'tournament.you'.tr()})' : p.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            'tournament.plays'.tr(args: ['${p.plays}']),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          const SizedBox(width: 12),
          Text(
            '${p.score}',
            style: const TextStyle(color: Color(0xFFFECA57), fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _CreateRequest {
  final String title;
  final String categoryName;
  final List<FriendUser> friends;

  const _CreateRequest({
    required this.title,
    required this.categoryName,
    required this.friends,
  });
}

/// Turnuva oluşturma diyaloğu: başlık, kategori ve arkadaş seçimi (2-7 arkadaş).
class _CreateTournamentDialog extends StatefulWidget {
  const _CreateTournamentDialog({required this.uid});

  final String uid;

  @override
  State<_CreateTournamentDialog> createState() => _CreateTournamentDialogState();
}

class _CreateTournamentDialogState extends State<_CreateTournamentDialog> {
  final TextEditingController _titleController = TextEditingController();
  late String _categoryName = SpeedRoundScreen.weeklyCategory().name;
  late final Future<List<FriendUser>> _friendsFuture =
      FriendService.streamFriends(widget.uid).first;
  List<FriendUser> _friends = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _friendsFuture.then((list) {
      if (mounted) setState(() => _friends = list);
    });
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final titleOk = _titleController.text.trim().isNotEmpty;
    final countOk = _selected.length >= TournamentService.minInvitees &&
        _selected.length <= TournamentService.maxInvitees;
    return titleOk && countOk;
  }

  void _submit() {
    final friends = _friends.where((f) => _selected.contains(f.uid)).toList();
    Navigator.of(context).pop(_CreateRequest(
      title: _titleController.text.trim(),
      categoryName: _categoryName,
      friends: friends,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final maxed = _selected.length >= TournamentService.maxInvitees;
    return GlassAlertDialog(
      title: Text('tournament.create_title'.tr()),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 40,
              decoration: InputDecoration(labelText: 'tournament.title_label'.tr()),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _categoryName,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'tournament.category_label'.tr()),
              items: [
                for (final c in AppCategories.categories)
                  DropdownMenuItem(value: c.name, child: Text(c.key.tr())),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _categoryName = v);
              },
            ),
            const SizedBox(height: 12),
            Text(
              'tournament.pick_friends'.tr(args: [
                '${TournamentService.minInvitees}',
                '${TournamentService.maxInvitees}',
              ]),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _friends.isEmpty
                  ? Center(child: Text('tournament.no_friends'.tr(), textAlign: TextAlign.center))
                  : ListView(
                      children: [
                        for (final f in _friends)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(f.username),
                            value: _selected.contains(f.uid),
                            onChanged: (!_selected.contains(f.uid) && maxed)
                                ? null
                                : (v) => setState(() {
                                      if (v == true) {
                                        _selected.add(f.uid);
                                      } else {
                                        _selected.remove(f.uid);
                                      }
                                    }),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text('tournament.create'.tr()),
        ),
      ],
    );
  }
}
