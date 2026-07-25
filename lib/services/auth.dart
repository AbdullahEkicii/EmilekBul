import 'package:firebase_auth/firebase_auth.dart';
import 'package:games_services/games_services.dart';
import 'user_service.dart'; // UserService'i import edin
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Misafir hesabını e-posta ile kalıcı hesaba dönüştür
  Future<UserCredential?> linkGuestWithEmail({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && user.isAnonymous) {
        // Mevcut profilini çek
        final currentProfile = await UserService.getUserProfile(user.uid);

        final credential =
            EmailAuthProvider.credential(email: email, password: password);
        final userCredential = await user.linkWithCredential(credential);

        // Yeni değerleri belirle (Girilenler öncelikli, yoksa eskiler)
        final newUsername = (username?.isNotEmpty == true)
            ? username!
            : (currentProfile?['username'] ?? '');
        final newFirstName = (firstName?.isNotEmpty == true)
            ? firstName!
            : (currentProfile?['firstName'] ?? '');
        final newLastName = (lastName?.isNotEmpty == true)
            ? lastName!
            : (currentProfile?['lastName'] ?? '');
        final currentAvatar = currentProfile?['avatarIndex'] ?? '0';

        // Profil güncelle
        await UserService.updateUserProfile(
          username: newUsername,
          firstName: newFirstName,
          lastName: newLastName,
          avatarIndex: currentAvatar,
          email: email,
        );

        // Misafir flag'ini kaldır
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'isGuest': false});

        return userCredential;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print("Link error: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  /// Kullanıcı kaydı (email & password ile) + Profil oluşturma
  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Profil oluştur
      if (userCredential.user != null) {
        await UserService.createUserProfile(
          uid: userCredential.user!.uid,
          email: email,
          username: username ?? '',
          firstName: firstName ?? '',
          lastName: lastName ?? '',
          avatarIndex: '0', // Varsayılan avatar
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Register error: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("Profile creation error: $e");
      return null;
    }
  }

  /// Giriş yapma (email & password ile)
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Giriş sonrası profil kontrolü
      if (userCredential.user != null) {
        final profileExists =
            await UserService.userProfileExists(userCredential.user!.uid);

        // Eğer profil yoksa oluştur (eski kullanıcılar için)
        if (!profileExists) {
          await UserService.createUserProfile(
            uid: userCredential.user!.uid,
            email: userCredential.user!.email ?? email,
          );
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Login error: ${e.code} - ${e.message}");
      return null;
    }
  }

  /// Çıkış yap
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Şifre sıfırlama e-postası gönder
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      print("Password reset error: ${e.code} - ${e.message}");
      return false;
    }
  }

  /// Şu anki kullanıcıyı getir
  User? get currentUser => _firebaseAuth.currentUser;

  /// Kullanıcı oturumunu dinle (stream)
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// E-posta doğrulaması gönder
  Future<bool> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
      return false;
    } catch (e) {
      print("Email verification error: $e");
      return false;
    }
  }

  /// E-posta doğrulandı mı kontrol et
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;

  /// Hesap silme
  Future<bool> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        // Önce Firestore'dan profili sil
        await UserService.deleteUserProfile(user.uid);
        // Sonra Auth'dan kullanıcıyı sil
        await user.delete();
        return true;
      }
      return false;
    } catch (e) {
      print("Delete account error: $e");
      return false;
    }
  }

  /// Şifre değiştirme
  Future<bool> updatePassword(String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      print("Update password error: ${e.code} - ${e.message}");
      return false;
    }
  }

  /// E-posta adresini güncelleme (yeni versiyonlarda verifyBeforeUpdateEmail kullanılır)
  Future<bool> updateEmail(String newEmail) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        // Yeni versiyonlarda updateEmail yerine verifyBeforeUpdateEmail kullanılır
        await user.verifyBeforeUpdateEmail(newEmail);

        // Doğrulama e-postası gönderildi, kullanıcı doğruladıktan sonra
        // Firestore'daki profil bilgisi otomatik güncellenecek
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      print("Update email error: ${e.code} - ${e.message}");
      return false;
    }
  }

  /// E-posta doğrulandıktan sonra Firestore profilini güncelle
  Future<void> updateEmailInFirestore(String newEmail) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        // Mevcut profil bilgilerini al
        final currentProfile = await UserService.getUserProfile(user.uid);
        if (currentProfile != null) {
          // Sadece e-posta adresini güncelle, diğer bilgileri koru
          await UserService.updateUserProfile(
            username: currentProfile['username'] ?? '',
            firstName: currentProfile['firstName'] ?? '',
            lastName: currentProfile['lastName'] ?? '',
            avatarIndex: currentProfile['avatarIndex'] ?? '0',
          );
        }
      }
    } catch (e) {
      print("Error updating email in Firestore: $e");
    }
  }

  /// Play Games ile Giriş/Link işlemini yönet
  Future<UserCredential?> handlePlayGamesLogin() async {
    const String webClientId =
        "561094034943-1tub3cs7vnav8r7ts42cdbltj09fu45f.apps.googleusercontent.com";
    try {
      // 1. Play Games'den Server Auth Code al
      final serverAuthCode = await GameAuth.getAuthCode(webClientId);

      if (serverAuthCode == null) {
        print("Play Games: Server Auth Code alınamadı.");
        return null;
      }

      final credential =
          PlayGamesAuthProvider.credential(serverAuthCode: serverAuthCode);
      final user = _firebaseAuth.currentUser;

      if (user != null && user.isAnonymous) {
        try {
          // Önce mevcut anonim hesabı bağlamayı dene (Veri kaybını önler)
          final result = await user.linkWithCredential(credential);

          // Link başarılıysa Firestore'da isGuest'i güncelle
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'isGuest': false});

          return result;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Hesap zaten başka birine bağlı, o hesaba geçiş yap
            print("Play Games hesabı zaten var, geçiş yapılıyor...");
            return await _firebaseAuth.signInWithCredential(credential);
          }
          rethrow;
        }
      } else {
        // Anonim değilse veya kullanıcı yoksa direkt giriş yap
        return await _firebaseAuth.signInWithCredential(credential);
      }
    } catch (e) {
      print("Play Games Auth error: $e");
      return null;
    }
  }

  /// Yeniden kimlik doğrulama (hassas işlemler için)
  Future<bool> reauthenticate(String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      print("Reauthentication error: ${e.code} - ${e.message}");
      return false;
    }
  }

  /// Firebase Auth hata mesajlarını Türkçe'ye çevir
  String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Yanlış şifre girdiniz.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalıdır.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
      case 'operation-not-allowed':
        return 'Bu işlem şu anda desteklenmiyor.';
      case 'requires-recent-login':
        return 'Bu işlem için yeniden giriş yapmanız gerekiyor.';
      case 'invalid-credential':
        return 'Geçersiz kimlik bilgileri.';
      case 'credential-already-in-use':
        return 'Bu kimlik bilgileri zaten başka bir hesapta kullanılıyor.';
      case 'invalid-verification-code':
        return 'Geçersiz doğrulama kodu.';
      case 'invalid-verification-id':
        return 'Geçersiz doğrulama ID\'si.';
      case 'network-request-failed':
        return 'Ağ bağlantısı hatası. İnternet bağlantınızı kontrol edin.';
      default:
        return 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }

  /// Auth state değişikliğini dinle ve e-posta güncellemelerini kontrol et
  void listenToAuthStateChanges() {
    _firebaseAuth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Kullanıcı giriş yapmışsa profil kontrolü yap
        final profileExists = await UserService.userProfileExists(user.uid);
        if (!profileExists) {
          await UserService.createUserProfile(
            uid: user.uid,
            email: user.email ?? '',
          );
        } else {
          // E-posta değişmiş olabilir, güncelle
          await updateEmailInFirestore(user.email ?? '');
        }
      }
    });
  }

  /// Play Games ile direkt giriş (Linklemesiz)
  Future<UserCredential?> signInWithPlayGames() async {
    const String webClientId =
        "561094034943-1tub3cs7vnav8r7ts42cdbltj09fu45f.apps.googleusercontent.com";
    try {
      final serverAuthCode = await GameAuth.getAuthCode(webClientId);
      if (serverAuthCode == null) return null;

      final credential =
          PlayGamesAuthProvider.credential(serverAuthCode: serverAuthCode);
      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      print("Play Games Sign-In Error: $e");
      return null;
    }
  }
}
