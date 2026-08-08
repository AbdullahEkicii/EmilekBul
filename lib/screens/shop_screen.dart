import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'token_screen.dart';
import 'edit_profile_screen.dart';
import '../services/user_service.dart';
import '../services/token_service.dart';
import '../services/achievement_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/navigation_buttons.dart';
import '../widgets/my_native_ad.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0; // 0: Avatars, 1: Frames, 2: Titles
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  List<Map<String, dynamic>> _avatars = [];

  void _generateShopAvatars() {
    _avatars = List.generate(41, (index) {
      final avatarIdx = index + 11; // filename: avatar_11.jpg to avatar_51.jpg
      final isAvailable = avatarIdx <= 30;

      return {
        'id': '${avatarIdx - 1}',
        'name': isAvailable ? 'Avatar $avatarIdx' : 'mystery_avatar',
        'cost': 2000,
        'path': 'avatars/avatar_$avatarIdx.jpg',
        'isAvailable': isAvailable,
      };
    });
  }

  final List<Map<String, dynamic>> _frames = [
    {'id': '1', 'name': 'shop.frame_gold', 'cost': 3000, 'color': Colors.amber},
    {
      'id': '2',
      'name': 'shop.frame_neon_blue',
      'cost': 1500,
      'color': Colors.cyanAccent
    },
    {
      'id': '3',
      'name': 'shop.frame_fiery',
      'cost': 2000,
      'color': Colors.redAccent
    },
    {
      'id': '4',
      'name': 'shop.frame_silver',
      'cost': 1000,
      'color': Colors.grey.shade300
    },
    {
      'id': '5',
      'name': 'shop.frame_emerald',
      'cost': 2500,
      'color': Colors.greenAccent
    },
    {
      'id': '6',
      'name': 'shop.frame_diamond',
      'cost': 3000,
      'color': Colors.blue.shade200
    },
    {
      'id': '7',
      'name': 'shop.frame_cyber',
      'cost': 2000,
      'color': Colors.purpleAccent
    },
    {
      'id': '8',
      'name': 'shop.frame_midnight',
      'cost': 1000,
      'color': Colors.indigo
    },
  ];

  final List<Map<String, dynamic>> _titles = [
    {'id': 'Çaylak', 'name': 'shop.title_novice', 'cost': 500},
    {'id': 'Bilge', 'name': 'shop.title_sage', 'cost': 1000},
    {'id': 'Uzman', 'name': 'shop.title_expert', 'cost': 1500},
    {'id': 'Efsane', 'name': 'shop.title_legend', 'cost': 2000},
    {'id': 'Dahi', 'name': 'shop.title_genius', 'cost': 2500},
    {'id': 'Üstad', 'name': 'shop.title_master', 'cost': 3000},
    {'id': 'Melek', 'name': 'shop.title_angel', 'cost': 3500},
    {'id': 'Prenses', 'name': 'shop.title_princess', 'cost': 4000},
    {'id': 'Kraliçe', 'name': 'shop.title_queen', 'cost': 4500},
    {'id': 'Kral', 'name': 'shop.title_king', 'cost': 5000},
    {'id': 'Yenilmez', 'name': 'shop.title_invincible', 'cost': 5000},
  ];

  @override
  void initState() {
    super.initState();
    _generateShopAvatars();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserService.getUserProfile();
    final localTokens = await TokenService.getTokenAmount();

    // Sync if needed (priority to local tokens as per user request flow)
    if (profile != null && profile['tokens'] != localTokens) {
      await UserService.updateUserTokens(localTokens);
      profile['tokens'] = localTokens;
    }

    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

  void _handlePurchase(String category, Map<String, dynamic> item) async {
    final result = await UserService.purchaseItem(
      category: category,
      itemId: item['id'],
      cost: item['cost'],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.redAccent,
        ),
      );
      if (result['success']) {
        // Local token'ları da güncelle
        await TokenService.updateTokenAmount(result['newBalance']);
        _loadUserProfile();
        
        // Başarımları kontrol et
        if (!mounted) return;
        await AchievementService.checkAndUnlockSmartShopper(context);
      }
    }
  }

  void _showPurchaseDialog(
      String category, Map<String, dynamic> item, bool isOwned) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 30,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'shop.product_detail'.tr(),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildItemPreview(category, item, size: 120),
              const SizedBox(height: 24),
              Text(
                item['name'].toString().tr(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (!isOwned)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${item['cost']} Token',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('shop.close'.tr(),
                          style: const TextStyle(color: Colors.white54)),
                    ),
                  ),
                  if (!isOwned)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handlePurchase(category, item);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('shop.buy'.tr(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // BG Orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.1),
              ),
            ),
          ),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: _buildHeader(),
              ),
              Expanded(
                child: _buildBody(),
              ),
              _buildBottomArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    switch (_selectedIndex) {
      case 0:
        return _buildGrid('avatars', _avatars);
      case 1:
        return _buildGrid('frames', _frames);
      case 2:
        return _buildGrid('titles', _titles);
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomArea() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: MyNativeAd(
                height: 120,
                factoryId: 'adFactoryExample',
                refreshInterval: 30,
              ),
            ),
            _buildCustomBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, 'shop.avatars'.tr(), Icons.face),
          _buildNavItem(1, 'shop.frames'.tr(), Icons.crop_square),
          _buildNavItem(2, 'shop.titles'.tr(), Icons.military_tech),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? Colors.blueAccent : Colors.grey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          AppBackButton(),
          const SizedBox(width: 10),
          Text(
            'shop.title'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EditProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TokenScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${_userProfile?['tokens'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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

  Widget _buildGrid(String category, List<Map<String, dynamic>> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        bool isOwned = false;

        if (category == 'avatars') {
          isOwned = List<String>.from(_userProfile?['ownedAvatars'] ?? [])
              .contains(item['id']);
          // Legacy support: If user is wearing this avatar, they own it
          if (!isOwned && (_userProfile?['avatarIndex'] ?? '0') == item['id']) {
            isOwned = true;
          }
        } else if (category == 'frames') {
          isOwned = List<String>.from(_userProfile?['ownedFrames'] ?? [])
              .contains(item['id']);
        } else if (category == 'titles') {
          isOwned = List<String>.from(_userProfile?['ownedTitles'] ?? [])
              .contains(item['id']);
        }

        return _buildShopCard(category, item, isOwned);
      },
    );
  }

  Widget _buildShopCard(
      String category, Map<String, dynamic> item, bool isOwned) {
    // Default to true if not specified (backend compatibility)
    final bool isAvailable = item['isAvailable'] ?? true;

    return GlassContainer(
      opacity: 0.05,
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: isAvailable ? 1.0 : 0.5,
            child: _buildItemPreview(category, item),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item['name'].toString().tr(),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: isAvailable ? 1.0 : 0.5),
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          if (!isAvailable)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined,
                      color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'shop.coming_soon'.tr(),
                      style: const TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            )
          else if (isOwned)
            Text('shop.owned'.tr(),
                style: const TextStyle(
                    color: Colors.greenAccent, fontWeight: FontWeight.bold))
          else
            ElevatedButton(
              onPressed: () => _showPurchaseDialog(category, item, isOwned),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on,
                      size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('${item['cost']}',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemPreview(String category, Map<String, dynamic> item,
      {double size = 60}) {
    final bool isAvailable = item['isAvailable'] ?? true;

    if (category == 'avatars') {
      if (!isAvailable) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blueAccent.withValues(alpha: 0.2),
                Colors.purpleAccent.withValues(alpha: 0.2),
              ],
            ),
            border: Border.all(color: Colors.white10, width: 2),
          ),
          child:
              Icon(Icons.lock_rounded, color: Colors.white24, size: size * 0.5),
        );
      }
      return CircleAvatar(
          radius: size / 2,
          backgroundImage: ResizeImage(
            AssetImage(UserService.getAvatarPath(item['id'])),
            width: (size * 2).toInt(),
            height: (size * 2).toInt(),
          ));
    } else if (category == 'frames') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 4),
          border: Border.all(color: item['color'], width: size / 15),
        ),
        child: Icon(Icons.person, color: Colors.white24, size: size / 2),
      );
    } else {
      return Container(
        padding:
            EdgeInsets.symmetric(horizontal: size / 5, vertical: size / 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(size / 8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            item['name'].toString().tr(),
            style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: size / 4),
          ),
        ),
      );
    }
  }
}
