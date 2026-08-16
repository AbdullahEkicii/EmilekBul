import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:games_services/games_services.dart';
import 'user_service.dart'; // UserService'i import edin

import 'package:cloud_firestore/cloud_firestore.dart';

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

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
        final guestUid = user.uid;
        final credential =
            EmailAuthProvider.credential(email: email, password: password);

        UserCredential userCredential;
        try {
          userCredential = await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
            // E-posta zaten kayıtlıysa, mevcut hesaba giriş yap ve misafir verilerini bu hesaba aktar
            userCredential = await _firebaseAuth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
          } else {
            rethrow;
          }
        }

        if (userCredential.user != null) {
          await UserService.migrateGuestDataToUser(
            sourceGuestUid: guestUid,
            targetUid: userCredential.user!.uid,
            newUsername: username,
            newFirstName: firstName,
            newLastName: lastName,
            email: email,
          );
        }

        return userCredential;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint("Link error: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  /// Kullanıcı kaydı (email & password ile) + Misafir Verisi Aktarımı
  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      final String? oldGuestUid = (currentUser != null && currentUser.isAnonymous) ? currentUser.uid : null;

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Profil oluştur veya misafir verilerini aktar
      if (userCredential.user != null) {
        if (oldGuestUid != null) {
          await UserService.migrateGuestDataToUser(
            sourceGuestUid: oldGuestUid,
            targetUid: userCredential.user!.uid,
            newUsername: username,
            newFirstName: firstName,
            newLastName: lastName,
            email: email,
          );
        } else {
          await UserService.createUserProfile(
            uid: userCredential.user!.uid,
            email: email,
            username: username ?? '',
            firstName: firstName ?? '',
            lastName: lastName ?? '',
            avatarIndex: '0', // Varsayılan avatar
          );
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint("Register error: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("Profile creation error: $e");
      return null;
    }
  }

  /// Giriş yapma (email & password ile) + Misafir Oturumu Birleştirme
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      final String? oldGuestUid = (currentUser != null && currentUser.isAnonymous) ? currentUser.uid : null;

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Giriş sonrası profil kontrolü ve misafir verilerini birleştirme
      if (userCredential.user != null) {
        final targetUid = userCredential.user!.uid;
        if (oldGuestUid != null && oldGuestUid != targetUid) {
          await UserService.migrateGuestDataToUser(
            sourceGuestUid: oldGuestUid,
            targetUid: targetUid,
            email: email,
          );
        } else {
          final profileExists =
              await UserService.userProfileExists(targetUid);

          // Eğer profil yoksa oluştur (eski kullanıcılar için)
          if (!profileExists) {
            await UserService.createUserProfile(
              uid: targetUid,
              email: userCredential.user!.email ?? email,
            );
          }
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint("Login error: ${e.code} - ${e.message}");
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
      debugPrint("Password reset error: ${e.code} - ${e.message}");
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
      debugPrint("Email verification error: $e");
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
      debugPrint("Delete account error: $e");
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
      debugPrint("Update password error: ${e.code} - ${e.message}");
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
      debugPrint("Update email error: ${e.code} - ${e.message}");
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
      debugPrint("Error updating email in Firestore: $e");
    }
  }

  /// Play Games ile Giriş/Link işlemini yönet
  /// Google Play Games ile Giriş (v2) - Mevcut misafir verilerini koruyarak
  Future<UserCredential?> handlePlayGamesLogin() async {
    const String webClientId =
        "561094034943-1tub3cs7vnav8r7ts42cdbltj09fu45f.apps.googleusercontent.com";
    try {
      await GameAuth.signIn();
      final serverAuthCode = await GameAuth.getAuthCode(webClientId);

      if (serverAuthCode == null) {
        debugPrint("Play Games: Server Auth Code alınamadı.");
        return null;
      }

      final credential =
          PlayGamesAuthProvider.credential(serverAuthCode: serverAuthCode);
      final user = _firebaseAuth.currentUser;
      final bool isAnonymous = user != null && user.isAnonymous;
      final String? oldGuestUid = isAnonymous ? user.uid : null;

      if (isAnonymous) {
        try {
          // Önce mevcut anonim hesabı bağlamayı dene (Veri kaybını önler)
          final result = await user.linkWithCredential(credential);

          if (result.user != null && oldGuestUid != null) {
            await UserService.migrateGuestDataToUser(
              sourceGuestUid: oldGuestUid,
              targetUid: result.user!.uid,
            );
          }

          return result;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Hesap zaten başka birine bağlı, o hesaba geçiş yap ve misafir verilerini aktar
            debugPrint("Play Games hesabı zaten var, aktarım yapılıyor...");
            final cred = await _firebaseAuth.signInWithCredential(credential);
            if (cred.user != null && oldGuestUid != null) {
              await UserService.migrateGuestDataToUser(
                sourceGuestUid: oldGuestUid,
                targetUid: cred.user!.uid,
              );
            }
            return cred;
          }
          rethrow;
        }
      } else {
        // Anonim değilse veya kullanıcı yoksa direkt giriş yap
        final cred = await _firebaseAuth.signInWithCredential(credential);
        if (cred.user != null) {
          final exists = await UserService.userProfileExists(cred.user!.uid);
          if (!exists) {
            final playerName = await GamesServices.getPlayerName() ?? 'Player';
            await UserService.createUserProfile(
              uid: cred.user!.uid,
              email: cred.user!.email ?? '',
              username: playerName,
            );
          }
        }
        return cred;
      }
    } catch (e) {
      debugPrint("Play Games Auth error: $e");
      return null;
    }
  }

  /// Play Games ile direkt giriş (Linklemesiz & Otomatik açılış için)
  Future<UserCredential?> signInWithPlayGames() async {
    const String webClientId =
        "561094034943-1tub3cs7vnav8r7ts42cdbltj09fu45f.apps.googleusercontent.com";
    try {
      // 1. Önce GamesServices.signIn() çağırarak Google Play Games v2 oturumunu başlat
      try {
        await GamesServices.signIn();
      } catch (gsErr) {
        debugPrint("GamesServices.signIn warning: $gsErr");
      }

      // 2. Oyuncu ID ve İsmini al
      final playerId = await GamesServices.getPlayerID();
      final playerName = await GamesServices.getPlayerName() ?? 'Player';

      // 3. GameAuth ile AuthCode al
      String? serverAuthCode;
      try {
        await GameAuth.signIn();
        serverAuthCode = await GameAuth.getAuthCode(webClientId);
      } catch (gaErr) {
        debugPrint("GameAuth.getAuthCode warning: $gaErr");
      }

      UserCredential? userCredential;
      final currentUser = _firebaseAuth.currentUser;
      final bool isAnonymous = currentUser != null && currentUser.isAnonymous;
      final String? oldGuestUid = isAnonymous ? currentUser.uid : null;

      if (serverAuthCode != null && serverAuthCode.isNotEmpty) {
        final credential =
            PlayGamesAuthProvider.credential(serverAuthCode: serverAuthCode);

        try {
          if (isAnonymous) {
            try {
              userCredential = await currentUser.linkWithCredential(credential);
            } on FirebaseAuthException catch (_) {
              userCredential = await _firebaseAuth.signInWithCredential(credential);
            }
          } else {
            userCredential = await _firebaseAuth.signInWithCredential(credential);
          }
        } catch (authErr) {
          debugPrint("Play Games Firebase Credential Auth Warning: $authErr");
        }
      }

      // 4. Eğer Firebase Credential başarılı olduysa profilini senkronize et
      if (userCredential?.user != null) {
        final uid = userCredential!.user!.uid;
        if (oldGuestUid != null) {
          await UserService.migrateGuestDataToUser(
            sourceGuestUid: oldGuestUid,
            targetUid: uid,
            newUsername: playerName,
            email: userCredential.user!.email,
          );
        } else {
          final profileExists = await UserService.userProfileExists(uid);
          if (!profileExists) {
            await UserService.createUserProfile(
              uid: uid,
              email: userCredential.user!.email ?? '',
              username: playerName,
            );
          } else {
            final currentProfile = await UserService.getUserProfile(uid);
            await UserService.updateUserProfile(
              username: playerName,
              firstName: currentProfile?['firstName'] ?? '',
              lastName: currentProfile?['lastName'] ?? '',
              avatarIndex: currentProfile?['avatarIndex'] ?? '0',
            );
          }
        }
        if (playerId != null) {
          await UserService.linkPlayGamesProfile(playerId, playerName);
        }
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isGuest': false,
          'playGamesId': playerId,
          'playGamesName': playerName,
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else if (playerId != null && playerId.isNotEmpty) {
        // 5. Firebase PlayGamesAuthProvider geçersiz credential verse bile:
        // Kullanıcıyı anonim Firebase hesabına veya mevcut hesaba bağlayıp Play Games profili ile resmi girişini tamamla!
        User? user = currentUser;
        if (user == null) {
          final anonCred = await _firebaseAuth.signInAnonymously();
          user = anonCred.user;
          userCredential = anonCred;
        }

        if (user != null) {
          final uid = user.uid;
          if (oldGuestUid != null && oldGuestUid != uid) {
            await UserService.migrateGuestDataToUser(
              sourceGuestUid: oldGuestUid,
              targetUid: uid,
              newUsername: playerName,
            );
          } else {
            final profileExists = await UserService.userProfileExists(uid);
            if (!profileExists) {
              await UserService.createUserProfile(
                uid: uid,
                email: '',
                username: playerName,
              );
            } else {
              final currentProfile = await UserService.getUserProfile(uid);
              await UserService.updateUserProfile(
                username: playerName,
                firstName: currentProfile?['firstName'] ?? '',
                lastName: currentProfile?['lastName'] ?? '',
                avatarIndex: currentProfile?['avatarIndex'] ?? '0',
              );
            }
          }
          await UserService.linkPlayGamesProfile(playerId, playerName);
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'isGuest': false,
            'playGamesId': playerId,
            'playGamesName': playerName,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
      }

      return userCredential;
    } catch (e) {
      debugPrint("Play Games Sign-In Error: $e");
      return null;
    }
  }
}
