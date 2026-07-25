import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final AudioPlayer _sfxPlayer = AudioPlayer();
  static final AudioPlayer _tickPlayer = AudioPlayer();
  static final AudioPlayer _musicPlayer = AudioPlayer();

  static bool _soundEnabled = true;
  static bool _musicEnabled = true;
  static bool _isInitialized = false;

  /// Ses servisini başlatır ve ayarları yükler
  static Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // lib/assets/sound/ yolunu direkt desteklemesi için prefix'i boş yapıyoruz
      AudioCache.instance.prefix = '';
      
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
      _isInitialized = true;
      
      print('🔊 SoundService başarıyla başlatıldı. SFX: $_soundEnabled, Müzik: $_musicEnabled');
    } catch (e) {
      print('⚠️ SoundService başlatılamadı: $e');
    }
  }

  static bool get isSoundEnabled => _soundEnabled;
  static bool get isMusicEnabled => _musicEnabled;

  /// Efekt seslerini açar/kapatır
  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_enabled', enabled);
      if (!enabled) {
        await _sfxPlayer.stop();
        await _tickPlayer.stop();
      }
    } catch (e) {
      print('Error saving sound setting: $e');
    }
  }

  /// Arka plan müziğini açar/kapatır
  static Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('music_enabled', enabled);
      if (!enabled) {
        await _musicPlayer.stop();
      }
    } catch (e) {
      print('Error saving music setting: $e');
    }
  }

  /// Doğru cevap sesi çalar
  static void playCorrect() {
    if (!_soundEnabled) return;
    try {
      _sfxPlayer.stop();
      _sfxPlayer.play(AssetSource('lib/assets/sound/correct_answer.mp3'));
    } catch (e) {
      print('Error playing correct sound: $e');
    }
  }

  /// Yanlış cevap sesi çalar
  static void playWrong() {
    if (!_soundEnabled) return;
    try {
      _sfxPlayer.stop();
      _sfxPlayer.play(AssetSource('lib/assets/sound/wrong_answer.mp3'));
    } catch (e) {
      print('Error playing wrong sound: $e');
    }
  }

  static bool _isTickPlaying = false;

  /// Süre azalırken tıkırtı sesini başlatır
  static Future<void> startClockTick() async {
    if (!_soundEnabled) return;
    _isTickPlaying = true;
    try {
      await _tickPlayer.setReleaseMode(ReleaseMode.loop);
      await _tickPlayer.play(AssetSource('lib/assets/sound/clock_tick.mp3'));
      if (!_isTickPlaying) {
        await _tickPlayer.stop();
      }
    } catch (e) {
      print('Error playing clock tick sound: $e');
    }
  }

  /// Tıkırtı sesini durdurur
  static Future<void> stopClockTick() async {
    _isTickPlaying = false;
    try {
      await _tickPlayer.stop();
    } catch (e) {
      print('Error stopping clock tick: $e');
    }
  }
}
