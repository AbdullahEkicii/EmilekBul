import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import 'shop_screen.dart';
import '../widgets/glass_container.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
import '../utils/app_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String _selectedAvatarIndex = '0';
  String _selectedFrameId = '0';
  String _selectedTitleId = '0'; // 0 or 'yok' means no title

  List<String> _ownedAvatars = [];
  List<String> _ownedFrames = [];
  List<String> _ownedTitles = [];

  // Tema Renkleri
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color secondaryDark = Color(0xFF1E293B);
  static const Color neonPurple = Color(0xFF8B5FFF);
  static const Color neonBlue = Color(0xFF4ECDC4);
  static const Color neonPink = Color(0xFFFF6B9D);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;

          // Localize username if it's a guest or follows Misafir pattern
          String loadedUsername = data['username'] ?? '';
          if (user.isAnonymous) {
            loadedUsername = AppUtils.localizeUsername(loadedUsername);
          }

          _usernameController.text = loadedUsername;
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';

          _selectedAvatarIndex = data['avatarIndex'] ?? '0';
          _selectedFrameId = data['equippedFrame'] ?? '0';
          _selectedTitleId = data['equippedTitle'] ?? '0';

          _ownedAvatars = List<String>.from(data['ownedAvatars'] ?? ['0']);
          _ownedFrames = List<String>.from(data['ownedFrames'] ?? ['0']);
          _ownedTitles = List<String>.from(data['ownedTitles'] ?? ['0']);

          _emailController.text = user.email ?? '';

          // Legacy Support: If current avatar is premium (>9) but not in owned list, add it locally
          // It will be saved to Firestore when they save profile
          int currentIdx = int.tryParse(_selectedAvatarIndex) ?? 0;
          if (currentIdx > 9 && !_ownedAvatars.contains(_selectedAvatarIndex)) {
            _ownedAvatars.add(_selectedAvatarIndex);
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('edit_profile.load_error'.tr(args: [e.toString()]));
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final isGuest = user.isAnonymous;

        // Misafir Kullanıcı Logic
        if (isGuest) {
          // Sadece kozmetik güncellemeler (Avatar, Çerçeve, Unvan)
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(
            {
              'avatarIndex': _selectedAvatarIndex,
              'equippedFrame': _selectedFrameId,
              'equippedTitle': _selectedTitleId,
              'ownedAvatars': _ownedAvatars,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } else {
          // Kayıtlı Kullanıcı Logic
          // 1. Kullanıcı Adı Değişikliği ve Müsaitlik Kontrolü
          final newUsername = _usernameController.text.trim();
          // Eğer kullanıcı adı değiştiyse kontrol et
          // Mevcut kullanıcı adını alıp karşılaştırabiliriz ama _isUsernameExists zaten ID kontrolü yapıyor.

          if (await _isUsernameExists(newUsername, user.uid)) {
            _showErrorSnackBar('edit_profile.username_taken'.tr());
            setState(() => _isSaving = false);
            return;
          }

          // 2. Profil Bilgilerini Güncelle (Email hariç)
          Map<String, dynamic> updateData = {
            'username': newUsername,
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'avatarIndex': _selectedAvatarIndex,
            'equippedFrame': _selectedFrameId,
            'equippedTitle': _selectedTitleId,
            'ownedAvatars': _ownedAvatars,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(
                updateData,
                SetOptions(merge: true),
              );
        }

        _showSuccessSnackBar('edit_profile.update_success'.tr());
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      _showErrorSnackBar('edit_profile.update_error'.tr(args: [e.toString()]));
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<bool> _isUsernameExists(String username, String currentUserId) async {
    if (username.isEmpty) return false;
    try {
      // Hem 'username' hem 'username_lower' alanlarını kontrol etmeliyiz
      // Ancak mevcut yapı username üzerine kurulu. İleride lowercase index eklenebilir.
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      for (var doc in querySnapshot.docs) {
        if (doc.id != currentUserId) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Stack(
        children: [
          // Background Backdrop Blur
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: GlassContainer(
                borderRadius: 32,
                opacity: 0.15,
                blur: 20,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'edit_profile.select_avatar'.tr(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'edit_profile.select_avatar_desc'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // 1. Free avatars (0-9)
                          final Set<String> availableAvatars = {};
                          for (int i = 0; i < 10; i++) {
                            availableAvatars.add(i.toString());
                          }
                          // 2. Owned avatars
                          availableAvatars.addAll(_ownedAvatars);

                          // Sort numerically
                          final List<String> displayList =
                              availableAvatars.toList()
                                ..sort((a, b) {
                                  int? iA = int.tryParse(a);
                                  int? iB = int.tryParse(b);
                                  if (iA != null && iB != null) {
                                    return iA.compareTo(iB);
                                  }
                                  return a.compareTo(b);
                                });

                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                            ),
                            itemCount: displayList.length,
                            itemBuilder: (context, index) {
                              final avatarId = displayList[index];
                              final isSelected =
                                  _selectedAvatarIndex == avatarId;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedAvatarIndex = avatarId;
                                  });
                                  Navigator.pop(context);
                                  HapticFeedback.mediumImpact();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? neonBlue
                                          : Colors.white.withValues(alpha: 0.1),
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: neonBlue.withValues(alpha: 0.3),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.05),
                                    backgroundImage: ResizeImage(
                                      AssetImage(
                                        UserService.getAvatarPath(avatarId),
                                      ),
                                      width: 120,
                                      height: 120,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: neonBlue),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: secondaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: neonPink),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: secondaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'edit_profile.title'.tr(),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.storefront_rounded, color: Colors.amber, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShopScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryDark, secondaryDark, primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: neonBlue))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          // Avatar Section
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                _showAvatarPicker();
                                HapticFeedback.mediumImpact();
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [neonPurple, neonBlue],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: neonPurple.withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 65,
                                          backgroundColor: secondaryDark,
                                          backgroundImage: ResizeImage(
                                            AssetImage(
                                              UserService.getAvatarPath(
                                                  _selectedAvatarIndex),
                                            ),
                                            width: 260,
                                            height: 260,
                                          ),
                                        ),
                                        if (_selectedFrameId != '0' && _selectedFrameId != 'yok')
                                          Container(
                                            width: 145,
                                            height: 145,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: UserService.getFrameColor(_selectedFrameId),
                                                width: 6,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: UserService.getFrameColor(_selectedFrameId).withValues(alpha: 0.5),
                                                  blurRadius: 15,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: neonBlue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: secondaryDark, width: 3),
                                      ),
                                      child: const Icon(Icons.edit,
                                          color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // --- CUSTOMIZATION SECTIONS ---
                          _buildSectionTitle(
                              'edit_profile.customize_appearance'.tr()),
                          const SizedBox(height: 16),
                          _buildFrameSelector(),
                          const SizedBox(height: 24),
                          _buildTitleSelector(),

                          const SizedBox(height: 48),

                          // Form Fields
                          GlassContainer(
                            padding: const EdgeInsets.all(24),
                            borderRadius: 24,
                            opacity: 0.1,
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _usernameController,
                                  label: 'edit_profile.username'.tr(),
                                  icon: Icons.alternate_email_rounded,
                                  enabled: FirebaseAuth
                                          .instance.currentUser?.isAnonymous ==
                                      false,
                                  validator: (v) {
                                    if (FirebaseAuth.instance.currentUser?.isAnonymous == true) return null;
                                    return (v == null || v.isEmpty) ? 'edit_profile.required_field'.tr() : null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                _buildTextField(
                                  controller: _firstNameController,
                                  label: 'edit_profile.name'.tr(),
                                  icon: Icons.person_outline_rounded,
                                  enabled: FirebaseAuth
                                          .instance.currentUser?.isAnonymous ==
                                      false,
                                  validator: (v) {
                                    if (FirebaseAuth.instance.currentUser?.isAnonymous == true) return null;
                                    return (v == null || v.isEmpty) ? 'edit_profile.required_field'.tr() : null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                _buildTextField(
                                  controller: _lastNameController,
                                  label: 'edit_profile.surname'.tr(),
                                  icon: Icons.person_outline_rounded,
                                  enabled: FirebaseAuth
                                          .instance.currentUser?.isAnonymous ==
                                      false,
                                  validator: (v) {
                                    if (FirebaseAuth.instance.currentUser?.isAnonymous == true) return null;
                                    return (v == null || v.isEmpty) ? 'edit_profile.required_field'.tr() : null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Save Button
                          GestureDetector(
                            onTap: _isSaving ? null : _saveProfile,
                            child: Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [neonPurple, Color(0xFF6C5CE7)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: neonPurple.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      )
                                    : Text(
                                        'edit_profile.save_changes'.tr(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFrameSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'edit_profile.frames'.tr(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _ownedFrames.length,
            separatorBuilder: (context, index) => const SizedBox(width: 15),
            itemBuilder: (context, index) {
              final frameId = _ownedFrames[index];
              final isSelected = _selectedFrameId == frameId;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedFrameId = frameId);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? neonBlue.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? neonBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: frameId == '0' || frameId == 'yok'
                      ? const Icon(Icons.block, color: Colors.white54)
                      : Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: UserService.getFrameColor(frameId),
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: UserService.getFrameColor(frameId).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.person, color: Colors.white24, size: 20),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'edit_profile.titles'.tr(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _ownedFrames
                  .isEmpty // Fallback text if empty? (shouldn't be, has '0')
              ? []
              : _ownedTitles.map((titleId) {
                  // Fixed: iterate ownedTitles
                  final isSelected = _selectedTitleId == titleId;
                  final titleName = titleId == '0' || titleId == 'yok'
                      ? 'shop.title_none'.tr()
                      : (AppConstants.titleKeys[titleId]?.tr() ?? titleId);
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedTitleId = titleId);
                      HapticFeedback.selectionClick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? neonBlue
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? neonBlue
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        titleName,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool isPassword = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: isPassword,
          enabled: enabled,
          style: TextStyle(
              color: enabled ? Colors.white : Colors.white54, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: neonBlue, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: neonBlue, width: 1),
            ),
            errorStyle: const TextStyle(color: neonPink),
          ),
        ),
      ],
    );
  }
}
