import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth? _customAuth;

  AuthService({FirebaseAuth? auth}) : _customAuth = auth;

  bool get isFirebaseAvailable {
    try {
      if (Firebase.apps.isEmpty) return false;
      final app = Firebase.app();
      if (app.options.projectId == 'ecotrack-mobile-app') return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    if (isFirebaseAvailable) {
      try {
        return FirebaseAuth.instance;
      } catch (e) {
        debugPrint('[AuthService] FirebaseAuth instance alınamadı: $e');
      }
    }
    return null;
  }

  Stream<User?> get authStateChanges {
    final a = _auth;
    if (a == null) {
      return Stream.value(null);
    }
    try {
      return a.authStateChanges();
    } catch (_) {
      return Stream.value(null);
    }
  }

  User? get currentUser {
    final a = _auth;
    if (a == null) return null;
    try {
      return a.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// E-posta ve şifre ile yeni kullanıcı kaydı
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final a = _auth;
    if (a == null) {
      throw Exception('Firebase bağlantısı henüz yapılandırılmadı.');
    }
    return await a.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// E-posta ve şifre ile giriş
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final a = _auth;
    if (a == null) {
      throw Exception('Firebase bağlantısı henüz yapılandırılmadı.');
    }
    return await a.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Anonim / Misafir Girişi
  Future<UserCredential> signInAnonymously() async {
    final a = _auth;
    if (a == null) {
      throw Exception('Firebase bağlantısı henüz yapılandırılmadı.');
    }
    return await a.signInAnonymously();
  }

  /// Şifre sıfırlama e-postası gönder
  Future<void> sendPasswordResetEmail({required String email}) async {
    final a = _auth;
    if (a == null) {
      throw Exception('Firebase bağlantısı henüz yapılandırılmadı.');
    }
    await a.sendPasswordResetEmail(email: email.trim());
  }

  /// Kullanıcının şifresini günceller
  Future<void> updatePassword(String newPassword) async {
    final a = _auth;
    final user = a?.currentUser;
    if (user == null) {
      throw Exception('Şifre güncellemek için oturum açık olmalıdır.');
    }
    await user.updatePassword(newPassword.trim());
  }

  /// Firebase Auth kullanıcı profil bilgilerini (ad, fotoğraf URL) günceller
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final a = _auth;
    final user = a?.currentUser;
    if (user != null) {
      if (displayName != null) await user.updateDisplayName(displayName.trim());
      if (photoURL != null) await user.updatePhotoURL(photoURL.trim());
    }
  }

  /// Oturumu kapat
  Future<void> signOut() async {
    final a = _auth;
    if (a != null) {
      try {
        await a.signOut();
      } catch (_) {}
    }
  }
}
