// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  final Map<String, Map<String, String>> newSettings = {
    'tr': {
      'full_screen': 'Tam Ekran',
      'full_screen_desc': 'Uygulamayı tam ekran modunda başlatır (Navigasyon çubuğunu gizler)'
    },
    'en': {
      'full_screen': 'Full Screen',
      'full_screen_desc': 'Starts the app in full screen mode (hides navigation bar)'
    },
    'es': {
      'full_screen': 'Pantalla Completa',
      'full_screen_desc': 'Inicia la aplicación en modo de pantalla completa (oculta la barra de navegación)'
    },
    'fr': {
      'full_screen': 'Plein Écran',
      'full_screen_desc': "Lance l'application en mode plein écran (masque la barre de navigation)"
    },
    'ru': {
      'full_screen': 'Полноэкранный режим',
      'full_screen_desc': 'Запускает приложение в полноэкранном режиме (скрывает панель навигации)'
    },
    'ar': {
      'full_screen': 'ملء الشاشة',
      'full_screen_desc': 'يبدأ التطبيق في وضع ملء الشاشة (يخفي شريط التنقل)'
    }
  };

  final dir = Directory('assets/translations');
  if (!dir.existsSync()) return;

  await for (var entity in dir.list()) {
    if (entity is File && entity.path.endsWith('.json')) {
      final lang = entity.uri.pathSegments.last.split('.').first;
      final contentStr = await entity.readAsString();
      final Map<String, dynamic> json = jsonDecode(contentStr);
      
      if (newSettings.containsKey(lang)) {
        if (json['settings'] == null) {
          json['settings'] = {};
        }
        json['settings']['full_screen'] = newSettings[lang]!['full_screen'];
        json['settings']['full_screen_desc'] = newSettings[lang]!['full_screen_desc'];

        final encoder = JsonEncoder.withIndent('  ');
        await entity.writeAsString(encoder.convert(json));
        print('Updated \${entity.path}');
      }
    }
  }
}
