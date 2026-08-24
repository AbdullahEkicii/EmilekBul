import 'dart:math';
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
    // 3 günlük deterministik indirim döngüsü
    final now = DateTime.now();
    final epochDays = now.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24);
    final discountCycleSeed = epochDays ~/ 3;

    // 0 ile 51 arasındaki indekslerden rastgele 10 tanesini indirimli seçelim
    final random = Random(discountCycleSeed);
    final List<int> allIndices = List.generate(52, (i) => i);
    allIndices.shuffle(random);
    final Set<int> discountedIndices = allIndices.take(10).toSet();

    _avatars = List.generate(52, (index) {
      final avatarIdx = index + 1; // 1 to 52 (avatar_1.jpg to avatar_52.jpg)
      
      // Zorlaştırılmış Prestij Fiyatlandırması:
      // 1-5: 1500 (Temel başlangıç avatarları)
      // 6-10: 2500 - 3000
      // 11-20: 4500 - 6500 (Orta seviye)
      // 21-35: 8000 - 12000 (Yüksek seviye)
      // 36-52: 15000 - 25000 (Nadir / Prestij)
      int originalCost;
      if (index < 5) {
        originalCost = 1500;
      } else if (index < 10) {
        originalCost = 2500 + ((index * 97) % 500); // 2500 - 3000
      } else if (index < 20) {
        originalCost = 4500 + ((index * 131) % 2000); // 4500 - 6500
      } else if (index < 35) {
        originalCost = 8000 + ((index * 173) % 4000); // 8000 - 12000
      } else {
        originalCost = 15000 + ((index * 211) % 10000); // 15000 - 25000
      }

      // 100'ün katına yuvarlayalım
      originalCost = (originalCost ~/ 100) * 100;

      final bool isOnSale = discountedIndices.contains(index);
      int finalCost = originalCost;
      int discountPercent = 0;

      if (isOnSale) {
        // %20 - %30 indirim
        discountPercent = (index % 2 == 0) ? 30 : 20;
        finalCost = ((originalCost * (100 - discountPercent)) ~/ 100 ~/ 50) * 50;
      }

      return {
        'id': '$avatarIdx',
        'name': 'Avatar $avatarIdx',
        'cost': finalCost,
        'originalCost': originalCost,
        'isOnSale': isOnSale,
        'discountPercent': discountPercent,
        'path': 'avatars/avatar_$avatarIdx.jpg',
        'isAvailable': true,
      };
    });
  }

  final List<Map<String, dynamic>> _frames = [
    {
      'id': '4',
      'name': 'shop.frame_silver',
      'cost': 3500,
      'color': Colors.grey.shade300
    },
    {
      'id': '8',
      'name': 'shop.frame_midnight',
      'cost': 4500,
      'color': Colors.indigo
    },
    {
      'id': '2',
      'name': 'shop.frame_neon_blue',
      'cost': 6500,
      'color': Colors.cyanAccent
    },
    {
      'id': '3',
      'name': 'shop.frame_fiery',
      'cost': 8500,
      'color': Colors.redAccent
    },
    {
      'id': '7',
      'name': 'shop.frame_cyber',
      'cost': 10000,
      'color': Colors.purpleAccent
    },
    {
      'id': '5',
      'name': 'shop.frame_emerald',
      'cost': 12500,
      'color': Colors.greenAccent
    },
    {
      'id': '1',
      'name': 'shop.frame_gold',
      'cost': 15000,
      'color': Colors.amber
    },
    {
      'id': '6',
      'name': 'shop.frame_diamond',
      'cost': 20000,
      'color': Colors.blue.shade200
    },
  ];

  final List<Map<String, dynamic>> _titles = [
    // Başlangıç Seviyesi Ünvanlar (2,500 - 6,000 Token)
    {'id': 'Çaylak', 'name': 'shop.title_novice', 'cost': 2500},
    {'id': 'Bilge', 'name': 'shop.title_sage', 'cost': 4000},
    {'id': 'Uzman', 'name': 'shop.title_expert', 'cost': 6000},

    // Orta Seviye Prestij Ünvanlar (8,500 - 16,000 Token)
    {'id': 'Efsane', 'name': 'shop.title_legend', 'cost': 8500},
    {'id': 'Dahi', 'name': 'shop.title_genius', 'cost': 10000},
    {'id': 'Üstad', 'name': 'shop.title_master', 'cost': 12000},
    {'id': 'Melek', 'name': 'shop.title_angel', 'cost': 13500},
    {'id': 'Prenses', 'name': 'shop.title_princess', 'cost': 15000},
    {'id': 'Leydi', 'name': 'shop.title_lady', 'cost': 16000},

    // Üst Seviye Nadir Ünvanlar (18,000 - 36,000 Token)
    {'id': 'Büyücü', 'name': 'shop.title_sorceress', 'cost': 18000},
    {'id': 'Yıldız', 'name': 'shop.title_star', 'cost': 20000},
    {'id': 'Kraliçe', 'name': 'shop.title_queen', 'cost': 24000},
    {'id': 'Kral', 'name': 'shop.title_king', 'cost': 24000},
    {'id': 'Sultan', 'name': 'shop.title_sultan', 'cost': 28000},
    {'id': 'Savaşçı Prenses', 'name': 'shop.title_warrior_princess', 'cost': 32000},
    {'id': 'İmparatoriçe', 'name': 'shop.title_empress', 'cost': 36000},

    // Efsanevi / Zirve Prestij Ünvanlar (42,000 - 75,000 Token)
    {'id': 'Tanrıça', 'name': 'shop.title_goddess', 'cost': 42000},
    {'id': 'Şampiyon', 'name': 'shop.title_champion', 'cost': 50000},
    {'id': 'Hükümdar', 'name': 'shop.title_sovereign', 'cost': 62000},
    {'id': 'Yenilmez', 'name': 'shop.title_invincible', 'cost': 75000},
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

  String _getItemDisplayName(String category, Map<String, dynamic> item) {
    if (category == 'avatars') {
      final id = item['id'];
      return 'shop.avatar_title'.tr(args: [id.toString()]);
    }
    return item['name'].toString().tr();
  }

  void _showPurchaseDialog(
      String category, Map<String, dynamic> item, bool isOwned) {
    final int userTokens = _userProfile?['tokens'] ?? 0;
    final int itemCost = item['cost'] ?? 0;
    final bool canAfford = userTokens >= itemCost;
    final bool isOnSale = item['isOnSale'] == true;
    final int originalCost = item['originalCost'] ?? itemCost;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: GlassContainer(
          borderRadius: 30,
          opacity: 0.2,
          blur: 25,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'shop.product_detail'.tr(),
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (isOnSale && !isOwned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '%${item['discountPercent']} ${'shop.sale_badge'.tr()}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Large Preview
              Hero(
                tag: 'shop_${category}_${item['id']}',
                child: _buildItemPreview(category, item, size: 140),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                _getItemDisplayName(category, item),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Price Row
              if (!isOwned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on,
                          color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      if (isOnSale) ...[
                        Text(
                          '$originalCost',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 15,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '$itemCost Token',
                        style: TextStyle(
                            color: isOnSale ? const Color(0xFFFF5252) : Colors.amber,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.greenAccent, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'shop.owned'.tr(),
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('shop.close'.tr(),
                          style: const TextStyle(color: Colors.white60, fontSize: 15)),
                    ),
                  ),
                  if (!isOwned) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: canAfford
                            ? () {
                                Navigator.pop(context);
                                _handlePurchase(category, item);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford ? Colors.blueAccent : Colors.grey.shade800,
                          elevation: canAfford ? 6 : 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          canAfford ? 'shop.buy'.tr() : 'shop.insufficient_funds'.tr(),
                          style: TextStyle(
                              color: canAfford ? Colors.white : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ],
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
          Positioned(
            bottom: 200,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withValues(alpha: 0.08),
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
                height: 65,
                factoryId: 'adFactorySmall',
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
          const AppBackButton(),
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
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        bool isOwned = false;

        if (category == 'avatars') {
          isOwned = List<String>.from(_userProfile?['ownedAvatars'] ?? [])
              .contains(item['id']);
          final currentAvatar = _userProfile?['avatarIndex']?.toString();
          if (!isOwned &&
              UserService.hasAvatar(currentAvatar) &&
              currentAvatar == item['id']) {
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
    final bool isOnSale = item['isOnSale'] == true && !isOwned;
    final int originalCost = item['originalCost'] ?? item['cost'];

    return GestureDetector(
      onTap: () => _showPurchaseDialog(category, item, isOwned),
      child: GlassContainer(
        opacity: 0.08,
        borderRadius: 22,
        padding: const EdgeInsets.all(12),
        border: isOnSale
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Hero(
                  tag: 'shop_${category}_${item['id']}',
                  child: _buildItemPreview(category, item, size: 76),
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _getItemDisplayName(category, item),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(height: 6),
                if (isOwned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'shop.owned'.tr(),
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on,
                            size: 13, color: Colors.amber),
                        const SizedBox(width: 4),
                        if (isOnSale) ...[
                          Text(
                            '$originalCost',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '${item['cost']}',
                          style: TextStyle(
                            color: isOnSale ? const Color(0xFFFF6B81) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
              ],
            ),

            // İndirim Rozeti
            if (isOnSale)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    '%${item['discountPercent']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemPreview(String category, Map<String, dynamic> item,
      {double size = 60}) {
    if (category == 'avatars') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: const Color(0xFF1E293B),
          backgroundImage: ResizeImage(
            AssetImage(UserService.getAvatarPath(item['id'])),
            width: (size * 2).toInt(),
            height: (size * 2).toInt(),
          ),
        ),
      );
    } else if (category == 'frames') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: item['color'], width: size / 14),
          boxShadow: [
            BoxShadow(
              color: (item['color'] as Color).withValues(alpha: 0.4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(Icons.person, color: Colors.white38, size: size / 2),
      );
    } else {
      return Container(
        padding:
            EdgeInsets.symmetric(horizontal: size / 5, vertical: size / 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(size / 6),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            item['name'].toString().tr(),
            style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: size / 3.5),
          ),
        ),
      );
    }
  }
}

