import 'package:firebase_auth/firebase_auth.dart';

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Kullanıcı kaydı (email & password ile)
  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Opsiyonel: Email doğrulama
      await userCredential.user?.sendEmailVerification();

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Register error: ${e.code} - ${e.message}");
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
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print("Password reset error: ${e.code} - ${e.message}");
    }
  }

  /// Şu anki kullanıcıyı getir
  User? get currentUser => _firebaseAuth.currentUser;

  /// Kullanıcı oturumunu dinle (stream)
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}
