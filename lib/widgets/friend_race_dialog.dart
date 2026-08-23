import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/duel_room_model.dart';
import '../models/category_model.dart';
import '../constants/app_categories.dart';
import '../services/duel_service.dart';
import '../services/user_service.dart';
import '../services/token_service.dart';
import '../services/bot_room_service.dart';
import '../screens/duel_room_screen.dart';
import '../utils/app_utils.dart';

class FriendRaceEntryDialog extends StatefulWidget {
  const FriendRaceEntryDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const FriendRaceEntryDialog(),
    );
  }

  @override
  State<FriendRaceEntryDialog> createState() => _FriendRaceEntryDialogState();
}

class _FriendRaceEntryDialogState extends State<FriendRaceEntryDialog> {
  int _selectedTab = 0; // 0: Açık Odalar, 1: Oda Oluştur, 2: Kod ile Katıl
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _botRoomPollTimer;

  // Initial Config for Create Room
  String _selectedCategory = 'Genel Kültür';
  String _selectedDifficulty = 'Orta';
  int _selectedQuestionCount = 5;
  int _selectedBet = 50;

  @override
  void initState() {
    super.initState();
    // Açık bot odası sayısını kontrol et
    BotRoomService.ensureMinimumBotRooms();

    // Kullanıcı açık odalar sekmesinde beklerken 12 saniyede bir odayı organik olarak tazele
    _botRoomPollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_selectedTab == 0 && mounted) {
        BotRoomService.ensureMinimumBotRooms();
      }
    });
  }

  @override
  void dispose() {
    _botRoomPollTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<DuelPlayer?> _getCurrentPlayer() async {
    final currentLang = context.locale.languageCode;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userData = await UserService.getUserProfile(user.uid);
    final tokens = await TokenService.getTokenAmount();

    return DuelPlayer(
      uid: user.uid,
      username: userData?['username']?.toString() ?? 'Oyuncu',
      avatarIndex: userData?['avatarIndex']?.toString() ?? '1',
      equippedFrame: userData?['equippedFrame']?.toString() ?? '0',
      equippedTitle: userData?['equippedTitle']?.toString() ?? 'yok',
      tokens: tokens,
      language: currentLang,
    );
  }

  Future<void> _handleCreateRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final player = await _getCurrentPlayer();
      if (player == null) {
        throw Exception('User not authenticated');
      }

      final config = DuelConfig(
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        questionCount: _selectedQuestionCount,
        betTokens: _selectedBet,
      );

      final roomCode = await DuelService.createRoom(
        hostPlayer: player,
        config: config,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close dialog

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DuelRoomScreen(
            roomCode: roomCode,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'duel.create_room_error'.tr();
        });
      }
    }
  }

  Future<void> _handleJoinRoomWithCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length < 4) {
      setState(() => _errorMessage = 'duel.enter_valid_code'.tr());
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final player = await _getCurrentPlayer();
      if (player == null) {
        throw Exception('User not authenticated');
      }

      final result = await DuelService.requestJoinRoom(
        roomCode: cleanCode,
        guestPlayer: player,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        if (result['isDirect'] == true) {
          Navigator.pop(context); // Close dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DuelRoomScreen(
                roomCode: cleanCode,
                isHost: result['isHost'] == true,
              ),
            ),
          );
        } else {
          // Join request sent, show waiting dialog
          _showWaitingApprovalDialog(cleanCode, player.uid);
        }
      } else {
        setState(() {
          _isLoading = false;
          final msgKey = result['message'] as String? ?? 'duel.join_room_error';
          _errorMessage = msgKey.tr();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'duel.join_room_error'.tr();
        });
      }
    }
  }

  void _showWaitingApprovalDialog(String cleanCode, String myUid) {
    StreamSubscription<DuelRoom?>? sub;
    bool isClosed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF9F43), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'duel.join_request_sent'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const CircularProgressIndicator(color: Color(0xFFFF9F43)),
              const SizedBox(height: 20),
              Text(
                'duel.waiting_host_approval'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                isClosed = true;
                sub?.cancel();
                DuelService.cancelJoinRequest(cleanCode, myUid);
                Navigator.of(dialogCtx).pop();
                if (mounted) setState(() => _isLoading = false);
              },
              child: Text(
                'duel.cancel_request'.tr(),
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    sub = DuelService.streamRoom(cleanCode).listen((room) {
      if (isClosed || !mounted) return;

      if (room == null || room.status == 'closed') {
        isClosed = true;
        sub?.cancel();
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isLoading = false;
          _errorMessage = 'duel.room_closed'.tr();
        });
        return;
      }

      // If approved or user is already guest
      if (room.guest?.uid == myUid || room.joinRequestStatus == 'approved') {
        isClosed = true;
        sub?.cancel();
        Navigator.of(context, rootNavigator: true).pop(); // close waiting dialog
        Navigator.pop(context); // close race dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DuelRoomScreen(
              roomCode: cleanCode,
              isHost: false,
            ),
          ),
        );
        return;
      }

      // If rejected
      if (room.joinRequestStatus == 'rejected' || (room.pendingGuest == null && room.guest?.uid != myUid)) {
        isClosed = true;
        sub?.cancel();
        Navigator.of(context, rootNavigator: true).pop(); // close waiting dialog
        setState(() {
          _isLoading = false;
          _errorMessage = 'duel.join_request_rejected'.tr();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF4F46E5)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'duel.friend_race'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Tabs Switcher
          _buildTabsHeader(),
          const SizedBox(height: 14),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Tab Body
          Expanded(
            child: _selectedTab == 0
                ? _buildOpenRoomsTab()
                : _selectedTab == 1
                    ? _buildCreateRoomTab()
                    : _buildJoinWithCodeTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsHeader() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'duel.tab_open_rooms'.tr(), Icons.public_rounded),
          _buildTabItem(1, 'duel.tab_create_room'.tr(), Icons.add_circle_outline_rounded),
          _buildTabItem(2, 'duel.tab_enter_code'.tr(), Icons.pin_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    final bool isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedTab = index;
          _errorMessage = null;
        }),
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
              Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 16),
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

  // TAB 1: Canlı Açık Odalar Listesi
  Widget _buildOpenRoomsTab() {
    return StreamBuilder<List<DuelRoom>>(
      stream: DuelService.streamOpenRooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF9F43)));
        }

        final rooms = snapshot.data ?? [];
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        // Filter out rooms owned by current user (so they don't see themselves as open opponent or allow them to re-enter)
        final openRooms = rooms.where((r) => r.guest == null).toList();

        if (openRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.meeting_room_outlined, color: Colors.white38, size: 40),
                ),
                const SizedBox(height: 14),
                Text(
                  'duel.no_open_rooms'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'duel.no_open_rooms_desc'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedTab = 1),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('duel.create_room_btn'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          itemCount: openRooms.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final room = openRooms[index];
            final isMyRoom = room.hostUid == myUid;

            final allCats = [...AppCategories.categories, ...AppCategories.bonusPoolCategories.whereType<CategoryItem>()];
            final cat = allCats.firstWhere(
              (c) => c.name == room.config.category,
              orElse: () => allCats.first,
            );

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  // Host Avatar
                  Builder(
                    builder: (context) {
                      final hasAvatar = UserService.hasAvatar(room.host.avatarIndex);
                      return CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF1E293B),
                        backgroundImage: hasAvatar
                            ? ResizeImage(
                                AssetImage(UserService.getAvatarPath(room.host.avatarIndex)),
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
                  const SizedBox(width: 12),

                  // Room Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppUtils.localizeUsername(room.host.username),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        const SizedBox(height: 3),
                        // Category Name Row
                        Row(
                          children: [
                            Icon(cat.icon, size: 12, color: cat.color),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                cat.key.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cat.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Badges Row (Difficulty + Question Count + Bet Tokens)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Difficulty Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppUtils.getDifficultyColor(room.config.difficulty).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppUtils.getDifficultyColor(room.config.difficulty).withValues(alpha: 0.45),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                AppUtils.localizeDifficulty(room.config.difficulty),
                                style: TextStyle(
                                  color: AppUtils.getDifficultyColor(room.config.difficulty),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            // Question Count Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white12, width: 0.8),
                              ),
                              child: Text(
                                '${room.config.questionCount} ${'duel.questions'.tr()}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            // Bet Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.monetization_on_rounded, color: Colors.orange, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${room.config.betTokens}',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Join / Re-enter Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleJoinRoomWithCode(room.roomCode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMyRoom ? const Color(0xFF6366F1) : const Color(0xFFFF9F43),
                      foregroundColor: isMyRoom ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    child: Text(
                      isMyRoom ? 'duel.my_room'.tr() : 'duel.join_room_btn'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),

                  // Close Own Room Button
                  if (isMyRoom) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'duel.leave'.tr(),
                      icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await DuelService.leaveRoom(room.roomCode, isHost: true, uid: myUid ?? '');
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // TAB 2: Oda Oluştur (İlk Özellikleri Seçerek)
  Widget _buildCreateRoomTab() {
    final allCats = [...AppCategories.categories, ...AppCategories.bonusPoolCategories];
    final currentCat = allCats.firstWhere(
      (c) => c.name == _selectedCategory,
      orElse: () => allCats.first,
    );

    final difficulties = [
      {'name': 'Kolay', 'key': 'category_ui.difficulty.easy', 'color': const Color(0xFF4CAF50)},
      {'name': 'Orta', 'key': 'category_ui.difficulty.medium', 'color': const Color(0xFFFF9800)},
      {'name': 'Zor', 'key': 'category_ui.difficulty.hard', 'color': const Color(0xFFE91E63)},
      {'name': 'Imkansız', 'key': 'category_ui.difficulty.impossible', 'color': const Color(0xFF9C27B0)},
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Kategori
          Text(
            'category_ui.preview_category'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1E293B),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (context) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: allCats.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final c = allCats[i];
                      return ListTile(
                        onTap: () {
                          setState(() => _selectedCategory = c.name);
                          Navigator.pop(context);
                        },
                        leading: Icon(c.icon, color: c.color),
                        title: Text(c.key.tr(), style: const TextStyle(color: Colors.white)),
                      );
                    },
                  );
                },
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(currentCat.icon, color: currentCat.color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      currentCat.key.tr(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Zorluk Seviyesi
          Text(
            'category_ui.preview_difficulty'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: difficulties.map((d) {
              final name = d['name'] as String;
              final color = d['color'] as Color;
              final isSel = name == _selectedDifficulty;

              return InkWell(
                onTap: () => setState(() => _selectedDifficulty = name),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? color : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSel ? color : Colors.white12),
                  ),
                  child: Text(
                    (d['key'] as String).tr(),
                    style: TextStyle(
                      color: isSel ? Colors.white : Colors.white70,
                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 3. Soru Sayısı
          Text(
            'duel.question_count'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [5, 6, 7].map((c) {
              final isSel = c == _selectedQuestionCount;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => setState(() => _selectedQuestionCount = c),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFFF9F43) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSel ? const Color(0xFFFF9F43) : Colors.white12),
                    ),
                    child: Text(
                      '$c',
                      style: TextStyle(
                        color: isSel ? Colors.black : Colors.white70,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 3. Bahis Miktarı
          Text(
            'duel.bet_amount'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [10, 25, 50, 100, 250, 500, 1000].map((b) {
              final isSel = b == _selectedBet;
              final isSpecial = DuelRoom.isSpecialHighBet(b);
              final feePercent = (DuelRoom.getCommissionRate(b) * 100).toInt();

              return InkWell(
                onTap: () => setState(() => _selectedBet = b),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSel
                        ? (isSpecial
                            ? const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFFEC4899)])
                            : const LinearGradient(colors: [Color(0xFFFF9F43), Color(0xFFFF5252)]))
                        : null,
                    color: isSel ? null : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel
                          ? Colors.transparent
                          : (isSpecial ? Colors.purpleAccent.withValues(alpha: 0.5) : Colors.white12),
                      width: isSpecial ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSpecial ? Icons.workspace_premium_rounded : Icons.monetization_on_rounded,
                        size: 14,
                        color: isSel
                            ? Colors.white
                            : (isSpecial ? const Color(0xFFC084FC) : Colors.orange),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        b >= 1000 ? '1K' : '$b',
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (isSpecial) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSel ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFA855F7).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '%$feePercent',
                            style: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFFD8B4FE),
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Prize & Fee Summary Card
          Builder(
            builder: (context) {
              final prize = DuelRoom.calculatePrize(_selectedBet);
              final feePercent = (DuelRoom.getCommissionRate(_selectedBet) * 100).toInt();
              final isSpecial = DuelRoom.isSpecialHighBet(_selectedBet);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSpecial
                        ? [const Color(0xFFA855F7).withValues(alpha: 0.2), const Color(0xFFEC4899).withValues(alpha: 0.1)]
                        : [const Color(0xFFFF9F43).withValues(alpha: 0.15), const Color(0xFF6366F1).withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSpecial ? const Color(0xFFA855F7).withValues(alpha: 0.4) : const Color(0xFFFF9F43).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSpecial ? Icons.military_tech_rounded : Icons.emoji_events_rounded,
                          color: isSpecial ? const Color(0xFFD8B4FE) : const Color(0xFFFFD56B),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'duel.pot_prize'.tr(),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                            ),
                            Text(
                              '$prize Token',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'duel.fee_info'.tr(args: ['$feePercent']),
                        style: TextStyle(
                          color: isSpecial ? const Color(0xFF34D399) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleCreateRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'duel.create_room_btn'.tr(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: Kod ile Katıl
  Widget _buildJoinWithCodeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          'duel.enter_code_desc'.tr(),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.pin_rounded, color: Color(0xFFFF9F43), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(6),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'duel.room_code_placeholder'.tr(),
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white70),
                tooltip: 'duel.paste'.tr(),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    setState(() {
                      _codeController.text = data!.text!.trim().toUpperCase();
                    });
                  }
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _handleJoinRoomWithCode(_codeController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9F43),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : Text(
                    'duel.join_room_btn'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }
}
