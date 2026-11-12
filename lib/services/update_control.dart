import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'startup_dialog_queue.dart';

Future<void> checkUpdate(BuildContext context) async {
  const jsonUrl =
      'https://raw.githubusercontent.com/AbdullahEkicii/EmilekBul/main/version.json';

  try {
    final response = await http.get(Uri.parse(jsonUrl)).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return;

    final json = jsonDecode(response.body);
    final minVersion = json['min_version'] as String;

    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    debugPrint('Current version: $currentVersion');
    debugPrint('Minimum version: $minVersion');

    bool forced = false;
    String shownVersion = minVersion;
    if (_compareVersions(currentVersion, minVersion) < 0) {
      forced = true;
    } else {
      // Opsiyonel: kapatılabilir öneri (günde en fazla 1 kez); hata/alan yoksa sessiz
      try {
        final rec = json['recommended_version'];
        if (rec is String && rec.isNotEmpty && _compareVersions(currentVersion, rec) < 0) {
          final prefs = await SharedPreferences.getInstance();
          final today = DateTime.now().toIso8601String().substring(0, 10);
          if (prefs.getString('update_recommended_shown_day') != today) {
            await prefs.setString('update_recommended_shown_day', today);
            shownVersion = rec;
          } else {
            return;
          }
        } else {
          return;
        }
      } catch (e) {
        debugPrint('recommended_version okunamadı: $e');
        return;
      }
    }
    // Opsiyonel sürüm notları: {"notes": {"tr": ["..."], "en": ["..."]}}; dil yoksa en'e düşer, hata sessiz
    List<String> notes = const [];
    try {
      final n = json['notes'];
      if (n is Map && context.mounted) {
        final list = n[context.locale.languageCode] ?? n['en'];
        if (list is List) {
          notes = list.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).take(6).toList();
        }
      }
    } catch (e) {
      debugPrint('Sürüm notları okunamadı: $e');
    }
    {
      if (!context.mounted) return;
      StartupDialogQueue.force(StartupDialogType.forcedUpdate);
      await showDialog(
        context: context,
        barrierDismissible: !forced,
        builder: (dialogContext) => PopScope(
          canPop: !forced,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7F7CFF),
                    Color(0xFFA67BFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF7F7CFF).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Update Icon with animation effect
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.system_update_alt,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Title
                  Text(
                    'update.title'.tr(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),

                  // Version info with modern styling
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.new_releases,
                          color: Colors.amber[300],
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'update.new_version'.tr(args: [shownVersion]),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Description
                  Text(
                    'update.description'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (notes.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'whats_new.title'.tr(),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 6),
                          for (final note in notes)
                            Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                '•  $note',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5, height: 1.35),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 32),

                  // Update Button with modern gradient
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final url = Uri.parse(
                            'https://play.google.com/store/apps/details?id=${info.packageName}');
                        launchUrl(url, mode: LaunchMode.externalApplication);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withValues(alpha: 0.95),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.download,
                                color: Color(0xFF7F7CFF),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'update.button'.tr(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7F7CFF),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!forced)
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'update.later'.tr(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
                      ),
                    ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('Sürüm kontrolü hatası: $e');
  }
}

int _compareVersions(String current, String min) {
  final currentParts = current.split('.').map(int.parse).toList();
  final minParts = min.split('.').map(int.parse).toList();

  for (int i = 0; i < 3; i++) {
    if (currentParts[i] > minParts[i]) return 1;
    if (currentParts[i] < minParts[i]) return -1;
  }
  return 0;
}
