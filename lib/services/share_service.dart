import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'analytics_service.dart';

class ShareService {
  static const String storeUrl =
      'https://play.google.com/store/apps/details?id=com.abdullahekici.emilekbul';

  /// Metni sistem paylaşım menüsüyle paylaşır; başarısız olursa panoya kopyalar.
  static Future<void> shareText(
    BuildContext context, {
    required String text,
    required String contentType,
  }) async {
    HapticFeedback.mediumImpact();
    final fullText = '$text\n$storeUrl';
    try {
      await SharePlus.instance.share(ShareParams(text: fullText));
      AnalyticsService.logShare(contentType: contentType);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: fullText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('share.copied'.tr()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  /// Üretilmiş bir PNG dosyasını metinle birlikte paylaşır; başarısız olursa metni panoya kopyalar.
  static Future<void> shareImageFile(
    BuildContext context, {
    required String path,
    required String text,
    required String contentType,
  }) async {
    HapticFeedback.mediumImpact();
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path, mimeType: 'image/png')], text: '$text\n$storeUrl'),
      );
      AnalyticsService.logShare(contentType: contentType);
    } catch (_) {
      if (context.mounted) {
        await shareText(context, text: text, contentType: contentType);
      }
    }
  }
}
