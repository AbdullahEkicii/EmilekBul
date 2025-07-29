import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> checkUpdate(BuildContext context) async {
  const jsonUrl =
      'https://raw.githubusercontent.com/AbdullahEkicii/EmilekBul/refs/heads/main/version.json';

  try {
    final response = await http.get(Uri.parse(jsonUrl));
    if (response.statusCode != 200) return;

    final json = jsonDecode(response.body);
    final minVersion = json['min_version'] as String;

    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    print('Current version: $currentVersion');
    print('Minimum version: $minVersion');

   if (_compareVersions(currentVersion, minVersion) < 0) {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async => false,
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
                color: Color(0xFF7F7CFF).withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
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
                'Zorunlu Güncelleme',
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
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
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
                      'Yeni Sürüm: $minVersion',
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
                'Uygulamayı kullanmaya devam etmek için en son sürüme güncellemeniz gerekiyor. Yeni özellikler ve iyileştirmeler sizi bekliyor!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              
              // Update Button with modern gradient
              Container(
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
                          Colors.white.withOpacity(0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
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
                          Icon(
                            Icons.download,
                            color: Color(0xFF7F7CFF),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Şimdi Güncelle',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7F7CFF),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
