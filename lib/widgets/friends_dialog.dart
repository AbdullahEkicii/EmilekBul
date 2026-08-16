import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_model.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../services/presence_service.dart';
import '../services/duel_invite_service.dart';
import '../utils/app_utils.dart';
import '../constants/app_constants.dart';
import 'friend_race_dialog.dart';

class FriendsDialog extends StatefulWidget {
  final int initialTab;
  const FriendsDialog({super.key, this.initialTab = 0});

  static void show(BuildContext context, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FriendsDialog(initialTab: initialTab),
    );
  }

  @override
  State<FriendsDialog> createState() => _FriendsDialogState();
}

class _FriendsDialogState extends State<FriendsDialog> {
  late int _selectedTab;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  final Map<String, FriendshipStatus> _searchStatusCache = {};

  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final results = await FriendService.searchUsers(query);
      if (!mounted) return;

      // Update status cache for each result
      for (final res in results) {
        final uid = res['uid'] as String;
        _searchStatusCache[uid] = await FriendService.checkFriendshipStatus(uid);
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _handleSendRequest(String toUid) async {
    HapticFeedback.lightImpact();
    final res = await FriendService.sendFriendRequest(toUid);
    if (!mounted) return;

    final msgKey = res['message'] as String? ?? 'common.error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msgKey.tr()),
        backgroundColor: res['success'] == true ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );

    if (res['success'] == true) {
      setState(() {
        _searchStatusCache[toUid] = FriendshipStatus.sentPending;
      });
    }
  }

  Future<void> _handleAcceptRequest(FriendRequest req) async {
    HapticFeedback.mediumImpact();
    final res = await FriendService.acceptFriendRequest(req);
    if (!mounted) return;

    final msgKey = res['message'] as String? ?? 'common.error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msgKey.tr()),
        backgroundColor: res['success'] == true ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleRejectRequest(String reqId) async {
    HapticFeedback.lightImpact();
    await FriendService.rejectFriendRequest(reqId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('friends.request_rejected'.tr()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showRemoveFriendConfirm(FriendUser friend) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'friends.remove_confirm_title'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'friends.remove_confirm_msg'.tr(args: [AppUtils.localizeUsername(friend.username)]),
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await FriendService.removeFriend(friend.uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('friends.friend_removed'.tr()),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('friends.remove'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final myUid = _myUid;

    if (myUid == null) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Center(
          child: Text(
            'auth.not_logged_in'.tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Color(0x2EFFFFFF), width: 1)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFEC4899)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'friends.title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tabs Header with Pending Requests Stream Badge
          StreamBuilder<int>(
            stream: FriendService.streamIncomingRequestsCount(myUid),
            builder: (context, reqSnapshot) {
              final pendingCount = reqSnapshot.data ?? 0;
              return _buildTabsHeader(pendingCount);
            },
          ),
          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: _selectedTab == 0
                ? _buildFriendsTab(myUid)
                : _selectedTab == 1
                    ? _buildRequestsTab(myUid)
                    : _buildSearchTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsHeader(int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'friends.my_friends'.tr(), Icons.group_rounded),
          _buildTabItem(1, 'friends.requests'.tr(), Icons.mark_email_unread_rounded, badgeCount: pendingCount),
          _buildTabItem(2, 'friends.search'.tr(), Icons.person_search_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon, {int badgeCount = 0}) {
    final bool isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 16),
                  if (badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: Arkadaşlarım Listesi
  Widget _buildFriendsTab(String myUid) {
    return StreamBuilder<List<FriendUser>>(
      stream: FriendService.streamFriends(myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_outline_rounded, color: Colors.white38, size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  'friends.no_friends'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'friends.no_friends_desc'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedTab = 2),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text('friends.search'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          itemCount: friends.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final friend = friends[index];
            final titleKey = AppConstants.titleKeys[friend.equippedTitle];
            final String displayTitle = (titleKey != null && titleKey.isNotEmpty) ? titleKey.tr() : friend.equippedTitle;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  // Avatar + Frame
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: UserService.getFrameColor(friend.equippedFrame),
                        width: 2.5,
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final hasAvatar = UserService.hasAvatar(friend.avatarIndex);
                        return CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF1E293B),
                          backgroundImage: hasAvatar
                              ? ResizeImage(
                                  AssetImage(UserService.getAvatarPath(
                                      friend.avatarIndex)),
                                  width: 88,
                                  height: 88,
                                )
                              : null,
                          child: hasAvatar
                              ? null
                              : const Icon(Icons.person_rounded,
                                  size: 20, color: Colors.white70),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppUtils.localizeUsername(friend.username),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.indigoAccent.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${'level_system.level'.tr()} ${friend.level}',
                                style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (friend.equippedTitle != '0' && friend.equippedTitle != 'yok') ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFFFFD56B), fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Canlı Çevrimiçi / Son Görülme Göstergesi
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: PresenceService.streamPresence(friend.uid),
                          builder: (context, presSnapshot) {
                            final data = presSnapshot.data?.data();
                            final isOnline = data?['isOnline'] == true;
                            DateTime? lastSeen;
                            if (data?['lastSeen'] is Timestamp) {
                              lastSeen = (data!['lastSeen'] as Timestamp).toDate();
                            }
                            final onlineReal = PresenceService.isUserOnline(lastSeen: lastSeen, isOnline: isOnline);
                            final statusText = PresenceService.formatLastSeen(lastSeen: lastSeen, isOnline: isOnline);

                            return Row(
                              children: [
                                Container(
                                  width: 6.5,
                                  height: 6.5,
                                  decoration: BoxDecoration(
                                    color: onlineReal ? const Color(0xFF22C55E) : Colors.white38,
                                    shape: BoxShape.circle,
                                    boxShadow: onlineReal
                                        ? [
                                            const BoxShadow(
                                              color: Color(0xFF22C55E),
                                              blurRadius: 4,
                                              spreadRadius: 0.5,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    color: onlineReal ? const Color(0xFF4ADE80) : Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Poke (Dürt) Action Button
                  IconButton(
                    tooltip: 'friends.poke'.tr(),
                    icon: const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 20),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final res = await DuelInviteService.pokeFriend(friend.uid);
                      if (!context.mounted) return;
                      final msg = res['message'] as String;
                      if (res['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg.tr()),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        final rem = res['remaining']?.toString() ?? '60';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg.tr(args: [rem])),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),

                  // 1v1 Race Action Button
                  IconButton(
                    tooltip: 'duel.invite_friend'.tr(),
                    icon: const Icon(Icons.sports_esports_rounded, color: Color(0xFFFFD56B), size: 22),
                    onPressed: () {
                      Navigator.pop(context);
                      FriendRaceEntryDialog.show(context);
                    },
                  ),

                  // Remove Friend Button
                  IconButton(
                    tooltip: 'friends.remove'.tr(),
                    icon: const Icon(Icons.person_remove_rounded, color: Colors.white38, size: 20),
                    onPressed: () => _showRemoveFriendConfirm(friend),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // TAB 2: Gelen İstekler Listesi
  Widget _buildRequestsTab(String myUid) {
    return StreamBuilder<List<FriendRequest>>(
      stream: FriendService.streamIncomingRequests(myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mail_outline_rounded, color: Colors.white38, size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  'friends.no_requests'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          itemCount: requests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final req = requests[index];

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  // Requester Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: UserService.getFrameColor(req.fromEquippedFrame),
                        width: 2.5,
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final hasAvatar = UserService.hasAvatar(req.fromAvatarIndex);
                        return CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF1E293B),
                          backgroundImage: hasAvatar
                              ? ResizeImage(
                                  AssetImage(UserService.getAvatarPath(
                                      req.fromAvatarIndex)),
                                  width: 88,
                                  height: 88,
                                )
                              : null,
                          child: hasAvatar
                              ? null
                              : const Icon(Icons.person_rounded,
                                  size: 20, color: Colors.white70),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Requester Name & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppUtils.localizeUsername(req.fromUsername),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'friends.incoming_requests'.tr(),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Decline Button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
                    onPressed: () => _handleRejectRequest(req.id),
                  ),

                  // Accept Button
                  ElevatedButton(
                    onPressed: () => _handleAcceptRequest(req),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('friends.accept'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // TAB 3: Arkadaş Ara Sekmesi
  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              icon: const Icon(Icons.search_rounded, color: Colors.white60, size: 20),
              hintText: 'friends.search_hint'.tr(),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
              border: InputBorder.none,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Search Results
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _searchController.text.trim().isEmpty
                  ? Center(
                      child: Text(
                        'friends.search_prompt'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'friends.no_search_results'.tr(),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13.5),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final uid = user['uid'] as String;
                            final status = _searchStatusCache[uid] ?? FriendshipStatus.none;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: UserService.getFrameColor(user['equippedFrame']?.toString()),
                                        width: 2,
                                      ),
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        final hasAvatar = UserService.hasAvatar(user['avatarIndex']?.toString());
                                        return CircleAvatar(
                                          radius: 21,
                                          backgroundColor: const Color(0xFF1E293B),
                                          backgroundImage: hasAvatar
                                              ? ResizeImage(
                                                  AssetImage(UserService.getAvatarPath(
                                                      user['avatarIndex']?.toString() ?? '0')),
                                                  width: 84,
                                                  height: 84,
                                                )
                                              : null,
                                          child: hasAvatar
                                              ? null
                                              : const Icon(Icons.person_rounded,
                                                  size: 20, color: Colors.white70),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Username & Level
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppUtils.localizeUsername(user['username']?.toString()),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${'level_system.level'.tr()} ${user['level'] ?? 1}',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Status Button
                                  _buildSearchActionButton(uid, status),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildSearchActionButton(String uid, FriendshipStatus status) {
    if (status == FriendshipStatus.friends) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
            const SizedBox(width: 4),
            Text(
              'friends.already_friends'.tr(),
              style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (status == FriendshipStatus.sentPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 14),
            const SizedBox(width: 4),
            Text(
              'friends.request_sent'.tr(),
              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _handleSendRequest(uid),
      icon: const Icon(Icons.person_add_rounded, size: 15),
      label: Text('friends.add_friend'.tr()),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
      ),
    );
  }
}
