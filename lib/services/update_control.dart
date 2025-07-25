import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> checkMandatoryUpdate(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;
  final packageName = packageInfo.packageName;
  final playStoreUrl =
      'https://play.google.com/store/apps/details?id=$packageName';

  try {
    final response = await http.get(Uri.parse(playStoreUrl));
    if (response.statusCode == 200) {
      final document = parse(response.body);
      final versionElement = document
          .getElementsByTagName('meta')
          .firstWhere(
            (element) => element.attributes['itemprop'] == 'softwareVersion',
            orElse: () => throw Exception('Sürüm bulunamadı'),
          );

      final storeVersion = versionElement.attributes['content']?.trim();

      if (storeVersion != null && storeVersion != currentVersion) {
        await showDialog(
          context: context,
          barrierDismissible: false, // Zorunlu güncelleme
          builder: (_) => WillPopScope(
            onWillPop: () async => false, // Geri tuşunu da engelle
            child: AlertDialog(
              title: Text('Zorunlu Güncelleme'),
              content: Text(
                'Uygulamanın yeni bir sürümü mevcut ($storeVersion). Devam edebilmek için güncelleme yapmanız gerekiyor.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    final launchUri = Uri.parse(playStoreUrl);
                    if (await canLaunchUrl(launchUri)) {
                      await launchUrl(
                        launchUri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text('Güncelle'),
                ),
              ],
            ),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Güncelleme kontrolü başarısız: $e');
  }
}
