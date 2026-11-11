import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  static final Map<String, _LocalAccountRecord> _localAccounts = {};

  User? _firebaseUser;
  UserModel? _userModel;
  bool _hasActiveSession = false;
  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<User?>? _authSub;

  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({
    AuthService? authService,
    FirestoreService? firestoreService,
  })  : _authService = authService ?? AuthService(),
        _firestoreService = firestoreService ?? FirestoreService() {
    _init();
  }

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isAuthenticated => _firebaseUser != null || _userModel != null;
  bool get hasActiveSession => _firebaseUser != null || _hasActiveSession;
  bool get isFirebaseAvailable => _authService.isFirebaseAvailable;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _init() {
    _setMockUser(); // İlk açılışta ve demo modunda profilin boş kalmaması için

    if (!_authService.isFirebaseAvailable) {
      debugPrint('[AuthProvider] Firebase aktif değil, yerel demo modu devrede.');
      return;
    }

    try {
      _firebaseUser = _authService.currentUser;
      _authSub = _authService.authStateChanges.listen((user) {
        _firebaseUser = user;
        if (user != null) {
          _hasActiveSession = true;
          _listenToUserProfile(user.uid);
        } else {
          _hasActiveSession = false;
          _userSub?.cancel();
          _setMockUser();
        }
      });
    } catch (e) {
      debugPrint('[AuthProvider] Firebase Auth dinleyicisi hatası: $e');
      _setMockUser();
    }
  }

  void _listenToUserProfile(String uid) {
    _userSub?.cancel();
    _userSub = _firestoreService.streamUserProfile(uid).listen(
      (profile) {
        if (profile != null) {
          _userModel = profile;
          notifyListeners();
        }
      },
      onError: (e) {
        debugPrint('[AuthProvider] Profil akış hatası: $e');
      },
    );
  }

  void _setMockUser() {
    _userModel = UserModel(
      uid: 'demo_user_1',
      fullName: 'Emirhan Sapmaz',
      email: 'emirhan@ecotrack.org',
      ecoPoints: 150,
      level: 'Doğa Dostu',
      recycledCount: 15,
      reportCount: 2,
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
    );
    notifyListeners();
  }

  /// Kullanıcı puanını ve sayaçlarını yerel olarak hemen günceller
  /// (Firebase aktifse Firestore akışı da ayrıca senkronize eder)
  void applyPointsUpdate(
    int points, {
    bool isRecycle = false,
    bool isReport = false,
  }) {
    if (_userModel == null) return;
    final newPoints = _userModel!.ecoPoints + points;
    String newLevel = 'Başlangıç';
    if (newPoints >= 200) {
      newLevel = 'Çevre Kahramanı';
    } else if (newPoints >= 80) {
      newLevel = 'Doğa Dostu';
    }

    _userModel = _userModel!.copyWith(
      ecoPoints: newPoints,
      level: newLevel,
      recycledCount:
          isRecycle ? _userModel!.recycledCount + 1 : _userModel!.recycledCount,
      reportCount:
          isReport ? _userModel!.reportCount + 1 : _userModel!.reportCount,
    );
    _syncCurrentLocalAccount();
    notifyListeners();
  }

  /// Kullanıcının ihbar sayacını sildiği kayıt sonrası 1 azaltır
  void decrementReportCount() {
    if (_userModel == null) return;
    final nextCount = (_userModel!.reportCount - 1).clamp(0, 999999);
    _userModel = _userModel!.copyWith(reportCount: nextCount);
    _syncCurrentLocalAccount();
    notifyListeners();
  }

  void _syncCurrentLocalAccount() {
    final user = _userModel;
    if (user == null) return;
    final key = user.email.trim().toLowerCase();
    final existing = _localAccounts[key];
    if (existing != null) {
      _localAccounts[key] = _LocalAccountRecord(
        password: existing.password,
        user: user,
      );
    }
  }

  /// Kullanıcının tüm profil detaylarını (ad, fotoğraf, bio, şehir, telefon) ve isteğe bağlı şifresini günceller
  Future<bool> updateProfileDetails({
    String? fullName,
    String? photoUrl,
    bool clearPhotoUrl = false,
    String? bio,
    String? city,
    String? phoneNumber,
    String? newPassword,
  }) async {
    if (_userModel == null) return false;
    _setLoading(true);
    _errorMessage = null;

    try {
      var updated = _userModel!.copyWith(
        fullName: fullName != null && fullName.trim().isNotEmpty
            ? fullName.trim()
            : _userModel!.fullName,
        photoUrl: photoUrl,
        clearPhotoUrl: clearPhotoUrl,
        bio: bio?.trim(),
        city: city?.trim(),
        phoneNumber: phoneNumber?.trim(),
      );

      // Şifre güncelleme
      if (newPassword != null && newPassword.trim().isNotEmpty) {
        final cleanPass = newPassword.trim();
        if (cleanPass.length < 6) {
          _errorMessage = 'Yeni şifre en az 6 karakter olmalıdır.';
          _setLoading(false);
          return false;
        }

        if (!_authService.isFirebaseAvailable) {
          final key = updated.email.trim().toLowerCase();
          _localAccounts[key] =
              _LocalAccountRecord(password: cleanPass, user: updated);
        } else {
          await _authService.updatePassword(cleanPass);
        }
      }

      // Firebase Auth displayName / photoURL güncelleme
      if (_authService.isFirebaseAvailable) {
        try {
          await _authService.updateProfile(
            displayName: updated.fullName,
            photoURL: updated.photoUrl,
          );
        } catch (_) {}
      }

      // Firestore güncelleme
      await _firestoreService.updateUserProfile(updated);

      _userModel = updated;
      _syncCurrentLocalAccount();
      _setLoading(false);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthException(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Profil güncellenirken hata oluştu: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Kullanıcının görünen adını yerel ve Firestore tarafında günceller
  Future<void> updateDisplayName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || _userModel == null) return;

    await updateProfileDetails(fullName: trimmed);
  }

  Future<bool> signIn(String email, String password) async {
    final cleanEmail = email.trim();
    _setLoading(true);
    _errorMessage = null;

    if (!_authService.isFirebaseAvailable) {
      final normalized = cleanEmail.toLowerCase();
      final savedAccount = _localAccounts[normalized];
      if (savedAccount != null) {
        if (savedAccount.password != password) {
          _errorMessage = 'Hatalı şifre. Lütfen tekrar deneyin.';
          _setLoading(false);
          return false;
        }
        _userModel = savedAccount.user;
      } else {
        final rawPrefix = cleanEmail.split('@').first.trim();
        final displayName = rawPrefix.isNotEmpty
            ? rawPrefix[0].toUpperCase() + rawPrefix.substring(1)
            : 'Çevre Gönüllüsü';
        _userModel = (_userModel ??
                UserModel(
                  uid: 'demo_user_1',
                  fullName: displayName,
                  email: cleanEmail,
                  level: 'Doğa Dostu',
                  createdAt: DateTime.now(),
                ))
            .copyWith(email: cleanEmail, fullName: displayName);
      }
      _hasActiveSession = true;
      _setLoading(false);
      return true;
    }

    try {
      final credential = await _authService.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      _firebaseUser = credential.user;
      if (_firebaseUser != null) {
        final profile =
            await _firestoreService.getUserProfile(_firebaseUser!.uid);
        if (profile != null) {
          _userModel = profile;
        } else {
          _userModel = UserModel(
            uid: _firebaseUser!.uid,
            fullName: _firebaseUser!.displayName?.trim().isNotEmpty == true
                ? _firebaseUser!.displayName!.trim()
                : cleanEmail.split('@').first,
            email: cleanEmail,
            level: 'Başlangıç',
            createdAt: DateTime.now(),
          );
        }
      }
      _hasActiveSession = true;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthException(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Giriş yapılamadı: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim();
    _setLoading(true);
    _errorMessage = null;

    if (!_authService.isFirebaseAvailable) {
      final normalized = cleanEmail.toLowerCase();
      if (_localAccounts.containsKey(normalized)) {
        _errorMessage = 'Bu e-posta adresi ile zaten bir hesap bulunuyor.';
        _setLoading(false);
        return false;
      }
      final newUser = UserModel(
        uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
        fullName: cleanName,
        email: cleanEmail,
        ecoPoints: 0,
        level: 'Başlangıç',
        recycledCount: 0,
        reportCount: 0,
        createdAt: DateTime.now(),
      );
      _localAccounts[normalized] = _LocalAccountRecord(
        password: password,
        user: newUser,
      );
      await _firestoreService.createUserProfile(newUser);
      _userModel = newUser;
      _hasActiveSession = true;
      _setLoading(false);
      return true;
    }

    try {
      final credential = await _authService.registerWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      _firebaseUser = credential.user;

      if (_firebaseUser != null) {
        try {
          await _firebaseUser!.updateDisplayName(cleanName);
        } catch (_) {}

        final newUser = UserModel(
          uid: _firebaseUser!.uid,
          fullName: cleanName,
          email: cleanEmail,
          ecoPoints: 0,
          level: 'Başlangıç',
          recycledCount: 0,
          reportCount: 0,
          createdAt: DateTime.now(),
        );

        await _firestoreService.createUserProfile(newUser);
        _userModel = newUser;
      }

      _hasActiveSession = true;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthException(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Kayıt oluşturulamadı: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      _errorMessage = 'Lütfen geçerli bir e-posta adresi girin.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    if (!_authService.isFirebaseAvailable) {
      _setLoading(false);
      return true;
    }

    try {
      await _authService.sendPasswordResetEmail(email: cleanEmail);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthException(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Şifre sıfırlama e-postası gönderilemedi: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<void> continueAsDemo() async {
    _errorMessage = null;
    if (_authService.isFirebaseAvailable && _authService.currentUser == null) {
      try {
        final cred = await _authService.signInAnonymously();
        _firebaseUser = cred.user;
      } catch (_) {}
    }
    _setMockUser();
    _hasActiveSession = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (_) {}
    _firebaseUser = null;
    _hasActiveSession = false;
    _setMockUser();
  }

  @visibleForTesting
  static void resetLocalAccounts() {
    _localAccounts.clear();
  }

  String _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Geçersiz e-posta adresi biçimi.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter kullanın.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı kurulamadı.';
      default:
        return e.message ?? 'Kimlik doğrulama işlemi başarısız oldu.';
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}

class _LocalAccountRecord {
  final String password;
  final UserModel user;

  const _LocalAccountRecord({
    required this.password,
    required this.user,
  });
}
