class AppLanguage {
  final String code;
  final String name; // Native name
  final String englishName;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.englishName,
    required this.flag,
  });
}

class AppLanguages {
  static const List<AppLanguage> languages = [
    AppLanguage(code: 'tr', name: 'Türkçe', englishName: 'Turkish', flag: '🇹🇷'),
    AppLanguage(code: 'en', name: 'English', englishName: 'English', flag: '🇺🇸'),
    AppLanguage(code: 'es', name: 'Español', englishName: 'Spanish', flag: '🇪🇸'),
    AppLanguage(code: 'de', name: 'Deutsch', englishName: 'German', flag: '🇩🇪'),
    AppLanguage(code: 'fr', name: 'Français', englishName: 'French', flag: '🇫🇷'),
    AppLanguage(code: 'it', name: 'Italiano', englishName: 'Italian', flag: '🇮🇹'),
    AppLanguage(code: 'pt', name: 'Português', englishName: 'Portuguese', flag: '🇵🇹'),
    AppLanguage(code: 'ru', name: 'Русский', englishName: 'Russian', flag: '🇷🇺'),
    AppLanguage(code: 'ar', name: 'العربية', englishName: 'Arabic', flag: '🇸🇦'),
    AppLanguage(code: 'zh', name: '中文', englishName: 'Chinese', flag: '🇨🇳'),
    AppLanguage(code: 'ja', name: '日本語', englishName: 'Japanese', flag: '🇯🇵'),
    AppLanguage(code: 'ko', name: '한국어', englishName: 'Korean', flag: '🇰🇷'),
    AppLanguage(code: 'hi', name: 'हिन्दी', englishName: 'Hindi', flag: '🇮🇳'),
    AppLanguage(code: 'id', name: 'Bahasa Indonesia', englishName: 'Indonesian', flag: '🇮🇩'),
    AppLanguage(code: 'nl', name: 'Nederlands', englishName: 'Dutch', flag: '🇳🇱'),
    AppLanguage(code: 'pl', name: 'Polski', englishName: 'Polish', flag: '🇵🇱'),
    AppLanguage(code: 'sv', name: 'Svenska', englishName: 'Swedish', flag: '🇸🇪'),
    AppLanguage(code: 'uk', name: 'Українська', englishName: 'Ukrainian', flag: '🇺🇦'),
    AppLanguage(code: 'vi', name: 'Tiếng Việt', englishName: 'Vietnamese', flag: '🇻🇳'),
    AppLanguage(code: 'th', name: 'ไทย', englishName: 'Thai', flag: '🇹🇭'),
    AppLanguage(code: 'cs', name: 'Čeština', englishName: 'Czech', flag: '🇨🇿'),
    AppLanguage(code: 'el', name: 'Ελληνικά', englishName: 'Greek', flag: '🇬🇷'),
    AppLanguage(code: 'ro', name: 'Română', englishName: 'Romanian', flag: '🇷🇴'),
    AppLanguage(code: 'hu', name: 'Magyar', englishName: 'Hungarian', flag: '🇭🇺'),
    AppLanguage(code: 'da', name: 'Dansk', englishName: 'Danish', flag: '🇩🇰'),
    AppLanguage(code: 'fi', name: 'Suomi', englishName: 'Finnish', flag: '🇫🇮'),
  ];

  static AppLanguage getLanguage(String code) {
    return languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => const AppLanguage(
        code: 'en',
        name: 'English',
        englishName: 'English',
        flag: '🇺🇸',
      ),
    );
  }
}
