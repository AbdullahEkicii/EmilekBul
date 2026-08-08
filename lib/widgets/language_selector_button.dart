import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'glass_container.dart';
import '../services/notification_service.dart';

class LanguageSelectorButton extends StatelessWidget {
  const LanguageSelectorButton({super.key});

  @override
  Widget build(BuildContext context) {
    // context.locale safely accessed
    final currentLocale = context.locale;

    String flag = "🇺🇸";
    String name = "English";

    switch (currentLocale.languageCode) {
      case 'tr':
        flag = "🇹🇷";
        name = "Türkçe";
        break;
      case 'es':
        flag = "🇪🇸";
        name = "Español";
        break;
      case 'fr':
        flag = "🇫🇷";
        name = "Français";
        break;
      case 'ar':
        flag = "🇸🇦";
        name = "العربية";
        break;
      case 'ru':
        flag = "🇷🇺";
        name = "Русский";
        break;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.mediumImpact();
            _showLanguageDialog(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  flag,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Language / Dil Seçin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildLanguageOption(
                context,
                'Turkish',
                'Türkçe',
                '🇹🇷',
                'tr',
              ),
              const Divider(color: Colors.white10),
              _buildLanguageOption(
                context,
                'English',
                'İngilizce',
                '🇺🇸',
                'en',
              ),
              const Divider(color: Colors.white10),
              _buildLanguageOption(
                context,
                'Spanish',
                'Español',
                '🇪🇸',
                'es',
              ),
              const Divider(color: Colors.white10),
              _buildLanguageOption(
                context,
                'French',
                'Français',
                '🇫🇷',
                'fr',
              ),
              const Divider(color: Colors.white10),
              _buildLanguageOption(
                context,
                'Arabic',
                'العربية',
                '🇸🇦',
                'ar',
              ),
              const Divider(color: Colors.white10),
              _buildLanguageOption(
                context,
                'Russian',
                'Русский',
                '🇷🇺',
                'ru',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String title,
    String subtitle,
    String flag,
    String code,
  ) {
    final isSelected = context.locale.languageCode == code;

    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blueAccent : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blueAccent)
          : null,
      onTap: () async {
        if (context.locale.languageCode != code) {
          await context.setLocale(Locale(code));
          // Bildirimleri hemen güncelle - await kullanmıyoruz, arkaplanda yapsın
          NotificationService.cancelAndReschedule();
        }
        if (context.mounted) {
          Navigator.pop(context);
          HapticFeedback.lightImpact();
        }
      },
    );
  }
}
