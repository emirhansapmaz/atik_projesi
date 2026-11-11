import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/waste_report_model.dart';

class FirestoreService {
  final FirebaseFirestore? _customFirestore;

  FirestoreService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  bool get isFirebaseAvailable {
    try {
      if (Firebase.apps.isEmpty) return false;
      final app = Firebase.app();
      // Dummy geliştirici projesiyse gerçek ağ çağrıları yerine yerel offline modda çalış
      if (app.options.projectId == 'ecotrack-mobile-app') return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    if (isFirebaseAvailable) {
      try {
        return FirebaseFirestore.instance;
      } catch (e) {
        debugPrint('[FirestoreService] Firestore instance alınamadı: $e');
      }
    }
    return null;
  }

  // --- YEREL ÇEVRİMDIŞI / FALLBACK BELLEK (Tüm servis örnekleri arasında senkron) ---
  static final Map<String, UserModel> _localUsers = {};
  static final List<WasteReportModel> _localReports = [];
  static bool _isSeeded = false;
  static bool _isUsersSeeded = false;
  static final StreamController<List<WasteReportModel>> _localReportsController =
      StreamController<List<WasteReportModel>>.broadcast();
  static final StreamController<List<UserModel>> _localUsersController =
      StreamController<List<UserModel>>.broadcast();

  static List<WasteReportModel> createDefaultSampleReports() {
    final now = DateTime.now();
    return [
      WasteReportModel(
        id: 'sample_1',
        userId: 'user_1',
        userName: 'Ahmet Yılmaz',
        wasteType: 'Plastik',
        confidence: 0.94,
        description: 'Park kenarında terkedilmiş pet şişeler ve poşetler.',
        imageUrl:
            'https://images.unsplash.com/photo-1530587191325-3db32d826c18?auto=format&fit=crop&w=600&q=80',
        latitude: 41.0063,
        longitude: 28.9757,
        addressText: 'Sultanahmet Meydanı, Fatih / İstanbul',
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      WasteReportModel(
        id: 'sample_2',
        userId: 'user_2',
        userName: 'Zeynep Kaya',
        wasteType: 'Cam',
        confidence: 0.89,
        description: 'Kaldırım kenarında kırık cam şişeler, tehlike oluşturuyor.',
        imageUrl:
            'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=600&q=80',
        latitude: 41.0181,
        longitude: 28.9728,
        addressText: 'Eminönü Vapur İskelesi Yakını, Fatih / İstanbul',
        status: 'resolved',
        resolvedBy: 'solver_1',
        createdAt: now.subtract(const Duration(days: 1)),
        resolvedAt: now.subtract(const Duration(hours: 5)),
      ),
      WasteReportModel(
        id: 'sample_3',
        userId: 'user_3',
        userName: 'Mehmet Demir',
        wasteType: 'Metal',
        confidence: 0.92,
        description: 'Bankların altında ezilmiş teneke içecek kutuları.',
        imageUrl:
            'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?auto=format&fit=crop&w=600&q=80',
        latitude: 41.0217,
        longitude: 28.9765,
        addressText: 'Karaköy Rıhtım, Beyoğlu / İstanbul',
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
    ];
  }

  static void _ensureSeededReports() {
    if (_isSeeded) return;
    _isSeeded = true;
    _localReports.addAll(createDefaultSampleReports());
  }

  static void _ensureSeededUsers() {
    if (_isUsersSeeded) return;
    _isUsersSeeded = true;
    final now = DateTime.now();
    final defaults = [
      UserModel(
        uid: 'user_top_1',
        fullName: 'Ahmet Yılmaz',
        email: 'ahmet@ecotrack.org',
        ecoPoints: 320,
        level: 'Çevre Kahramanı',
        recycledCount: 28,
        reportCount: 4,
        createdAt: now.subtract(const Duration(days: 40)),
      ),
      UserModel(
        uid: 'user_top_2',
        fullName: 'Zeynep Kaya',
        email: 'zeynep@ecotrack.org',
        ecoPoints: 245,
        level: 'Çevre Kahramanı',
        recycledCount: 21,
        reportCount: 3,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      UserModel(
        uid: 'user_top_3',
        fullName: 'Mehmet Demir',
        email: 'mehmet@ecotrack.org',
        ecoPoints: 195,
        level: 'Doğa Dostu',
        recycledCount: 18,
        reportCount: 2,
        createdAt: now.subtract(const Duration(days: 24)),
      ),
      UserModel(
        uid: 'user_4',
        fullName: 'Elif Şahin',
        email: 'elif@ecotrack.org',
        ecoPoints: 110,
        level: 'Doğa Dostu',
        recycledCount: 10,
        reportCount: 1,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      UserModel(
        uid: 'user_5',
        fullName: 'Can Öztürk',
        email: 'can@ecotrack.org',
        ecoPoints: 75,
        level: 'Başlangıç',
        recycledCount: 7,
        reportCount: 1,
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      UserModel(
        uid: 'user_6',
        fullName: 'Selin Arslan',
        email: 'selin@ecotrack.org',
        ecoPoints: 40,
        level: 'Başlangıç',
        recycledCount: 4,
        reportCount: 0,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ];
    for (final user in defaults) {
      _localUsers.putIfAbsent(user.uid, () => user);
    }
  }

  static List<UserModel> _sortedTopUsers() {
    final sorted = _localUsers.values.toList()
      ..sort((a, b) => b.ecoPoints.compareTo(a.ecoPoints));
    return List<UserModel>.unmodifiable(sorted.take(20));
  }

  static int _purgeExpiredLocalReports({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final before = _localReports.length;
    _localReports.removeWhere((report) => report.isExpiredAt(reference));
    return before - _localReports.length;
  }

  static List<WasteReportModel> _reportsForUser(String userId) {
    _purgeExpiredLocalReports();
    final filtered = _localReports
        .where((r) => r.userId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<WasteReportModel>.unmodifiable(filtered);
  }

  static void _emitLocalReports() {
    _purgeExpiredLocalReports();
    if (!_localReportsController.isClosed) {
      _localReportsController.add(List<WasteReportModel>.unmodifiable(_localReports));
    }
  }

  static void _emitLocalUsers() {
    if (!_localUsersController.isClosed) {
      _localUsersController.add(_sortedTopUsers());
    }
  }

  /// Testlerde temiz başlangıç durumu oluşturmak için yerel demo verilerini sıfırlar
  @visibleForTesting
  static void resetLocalDemoData() {
    _localUsers.clear();
    _localReports.clear();
    _isSeeded = false;
    _isUsersSeeded = false;
    _ensureSeededReports();
    _emitLocalReports();
  }

  /// Çevrimdışı/demo modunda yerel bellekten kullanıcı profilini okur (test ve senkronizasyon için)
  UserModel? getLocalUser(String uid) => _localUsers[uid];

  // --- KULLANICI İŞLEMLERİ ---

  /// Yeni kullanıcı profilini Firestore'a (veya yerel belleğe) kaydeder
  Future<void> createUserProfile(UserModel user) async {
    _localUsers[user.uid] = user;
    _emitLocalUsers();
    final fs = _firestore;
    if (fs == null) return;

    try {
      await fs.collection('users').doc(user.uid).set(user.toJson());
    } catch (e) {
      debugPrint('[FirestoreService] Profil Firestore\'a yazılamadı (yerel kaydedildi): $e');
    }
  }

  /// Kullanıcının görünen adını günceller
  Future<void> updateUserName(String uid, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final existing = _localUsers[uid];
    if (existing != null) {
      _localUsers[uid] = existing.copyWith(fullName: trimmed);
      _emitLocalUsers();
    }

    final fs = _firestore;
    if (fs == null) return;

    try {
      await fs.collection('users').doc(uid).update({'fullName': trimmed});
    } catch (e) {
      debugPrint('[FirestoreService] updateUserName hatası: $e');
    }
  }

  /// Kullanıcı profilini kapsamlı olarak günceller (ad, fotoğraf, bio, şehir, telefon vb.)
  Future<void> updateUserProfile(UserModel updatedUser) async {
    _localUsers[updatedUser.uid] = updatedUser;
    _emitLocalUsers();

    final fs = _firestore;
    if (fs == null) return;

    try {
      await fs.collection('users').doc(updatedUser.uid).set(
            updatedUser.toJson(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('[FirestoreService] updateUserProfile hatası: $e');
    }
  }

  /// 'users' koleksiyonunu 'ecoPoints' alanına göre büyükten küçüğe sıralayıp ilk 20 kullanıcıyı dinler
  Stream<List<UserModel>> getLeaderboardStream() async* {
    final fs = _firestore;
    if (fs == null) {
      _ensureSeededUsers();
      yield _sortedTopUsers();
      yield* _localUsersController.stream;
      return;
    }

    try {
      yield* fs
          .collection('users')
          .orderBy('ecoPoints', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList())
          .handleError((error) {
        debugPrint('[FirestoreService] getLeaderboardStream hatası: $error');
      });
    } catch (e) {
      debugPrint('[FirestoreService] getLeaderboardStream başlatılamadı: $e');
      _ensureSeededUsers();
      yield _sortedTopUsers();
      yield* _localUsersController.stream;
    }
  }

  /// Kullanıcı verilerini anlık (Stream) olarak dinler
  Stream<UserModel?> streamUserProfile(String uid) {
    final fs = _firestore;
    if (fs == null) {
      return Stream.value(_localUsers[uid]);
    }

    try {
      return fs.collection('users').doc(uid).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) {
          return _localUsers[uid];
        }
        return UserModel.fromFirestore(doc);
      }).handleError((error) {
        debugPrint('[FirestoreService] streamUserProfile hatası, yerel veri kullanılıyor: $error');
        return _localUsers[uid];
      });
    } catch (e) {
      debugPrint('[FirestoreService] streamUserProfile başlatılamadı: $e');
      return Stream.value(_localUsers[uid]);
    }
  }

  /// Belirtilen kullanıcının güncel profilini tek seferlik getirir
  Future<UserModel?> getUserProfile(String uid) async {
    final fs = _firestore;
    if (fs == null) {
      return _localUsers[uid];
    }

    try {
      final doc = await fs.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return _localUsers[uid];
      }
      return UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[FirestoreService] getUserProfile hatası: $e');
      return _localUsers[uid];
    }
  }

  /// Kullanıcıya puan ekler ve puan barajına göre seviye güncellemesi yapar
  Future<void> addEcoPoints(String uid, int points, {bool isRecycle = false}) async {
    // Önce yerel veriyi güncelle (anında tepki)
    final existing = _localUsers[uid] ??
        UserModel(
          uid: uid,
          fullName: 'EcoTrack Kullanıcısı',
          email: '$uid@ecotrack.local',
          createdAt: DateTime.now(),
        );
    final newPoints = existing.ecoPoints + points;
    String newLevel = 'Başlangıç';
    if (newPoints >= 200) {
      newLevel = 'Çevre Kahramanı';
    } else if (newPoints >= 80) {
      newLevel = 'Doğa Dostu';
    }

    _localUsers[uid] = existing.copyWith(
      ecoPoints: newPoints,
      level: newLevel,
      recycledCount: isRecycle ? existing.recycledCount + 1 : existing.recycledCount,
    );
    _emitLocalUsers();

    final fs = _firestore;
    if (fs == null) return;

    try {
      final userRef = fs.collection('users').doc(uid);
      await fs.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return;

        final data = snapshot.data();
        final currentPoints = (data?['ecoPoints'] as num?)?.toInt() ?? 0;
        final currentRecycled = (data?['recycledCount'] as num?)?.toInt() ?? 0;
        final updatedPoints = currentPoints + points;

        String updatedLevel = 'Başlangıç';
        if (updatedPoints >= 200) {
          updatedLevel = 'Çevre Kahramanı';
        } else if (updatedPoints >= 80) {
          updatedLevel = 'Doğa Dostu';
        }

        final updateData = <String, dynamic>{
          'ecoPoints': updatedPoints,
          'level': updatedLevel,
        };

        if (isRecycle) {
          updateData['recycledCount'] = currentRecycled + 1;
        }

        transaction.update(userRef, updateData);
      });
    } catch (e) {
      debugPrint('[FirestoreService] addEcoPoints Firestore senkronizasyon hatası: $e');
    }
  }

  // --- ATIK RAPORLARI (İHBAR) İŞLEMLERİ ---

  /// Tüm atık raporlarını kronolojik sırada canlı akış (Stream) olarak dinler
  Stream<List<WasteReportModel>> getWasteReportsStream() async* {
    final fs = _firestore;
    if (fs == null) {
      _ensureSeededReports();
      _purgeExpiredLocalReports();
      yield List<WasteReportModel>.unmodifiable(_localReports);
      yield* _localReportsController.stream.map((reports) {
        final now = DateTime.now();
        return List<WasteReportModel>.unmodifiable(
          reports.where((r) => !r.isExpiredAt(now)),
        );
      });
      return;
    }

    try {
      yield* fs
          .collection('waste_reports')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            final now = DateTime.now();
            final all = snapshot.docs
                .map((doc) => WasteReportModel.fromFirestore(doc))
                .toList();
            _scheduleExpiredFirestoreCleanup(fs, all, now);
            return all.where((r) => !r.isExpiredAt(now)).toList();
          })
          .handleError((error) {
        debugPrint('[FirestoreService] getWasteReportsStream hatası: $error');
      });
    } catch (e) {
      debugPrint('[FirestoreService] getWasteReportsStream başlatılamadı: $e');
      _ensureSeededReports();
      _purgeExpiredLocalReports();
      yield List<WasteReportModel>.unmodifiable(_localReports);
      yield* _localReportsController.stream;
    }
  }

  /// Belirli bir kullanıcının açtığı atık ihbarlarını tarihe göre azalan sırada canlı dinler
  Stream<List<WasteReportModel>> getUserReportsStream(String userId) async* {
    final fs = _firestore;
    if (fs == null) {
      _ensureSeededReports();
      yield _reportsForUser(userId);
      yield* _localReportsController.stream.map((_) => _reportsForUser(userId));
      return;
    }

    try {
      yield* fs
          .collection('waste_reports')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            final now = DateTime.now();
            final all = snapshot.docs
                .map((doc) => WasteReportModel.fromFirestore(doc))
                .toList();
            _scheduleExpiredFirestoreCleanup(fs, all, now);
            return all.where((r) => !r.isExpiredAt(now)).toList();
          })
          .handleError((error) {
        debugPrint('[FirestoreService] getUserReportsStream hatası: $error');
      });
    } catch (e) {
      debugPrint('[FirestoreService] getUserReportsStream başlatılamadı: $e');
      _ensureSeededReports();
      yield _reportsForUser(userId);
      yield* _localReportsController.stream.map((_) => _reportsForUser(userId));
    }
  }

  /// Mevcut MapProvider uyumluluğu için canlı atık raporları akışı
  Stream<List<WasteReportModel>> streamWasteReports() => getWasteReportsStream();

  /// Atık raporlarını tek seferlik getirir
  Future<List<WasteReportModel>> getWasteReports() async {
    final fs = _firestore;
    if (fs == null) {
      _ensureSeededReports();
      final removed = _purgeExpiredLocalReports();
      if (removed > 0) _emitLocalReports();
      return List<WasteReportModel>.unmodifiable(_localReports);
    }

    try {
      final snapshot = await fs
          .collection('waste_reports')
          .orderBy('createdAt', descending: true)
          .get();
      final now = DateTime.now();
      final all = snapshot.docs
          .map((doc) => WasteReportModel.fromFirestore(doc))
          .toList();
      _scheduleExpiredFirestoreCleanup(fs, all, now);
      return all.where((r) => !r.isExpiredAt(now)).toList();
    } catch (e) {
      debugPrint('[FirestoreService] getWasteReports hatası: $e');
      _ensureSeededReports();
      _purgeExpiredLocalReports();
      return List<WasteReportModel>.unmodifiable(_localReports);
    }
  }

  /// Temizlenmesinin üzerinden 12 saat geçmiş ihbarları temizler
  Future<int> purgeExpiredReports({DateTime? now}) async {
    final reference = now ?? DateTime.now();
    _ensureSeededReports();
    var removedCount = _purgeExpiredLocalReports(now: reference);
    if (removedCount > 0) {
      _emitLocalReports();
    }

    final fs = _firestore;
    if (fs == null) return removedCount;

    try {
      final snapshot = await fs
          .collection('waste_reports')
          .where('status', isEqualTo: 'resolved')
          .get();
      for (final doc in snapshot.docs) {
        final report = WasteReportModel.fromFirestore(doc);
        if (report.isExpiredAt(reference)) {
          await doc.reference.delete();
          removedCount++;
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] Süresi dolan ihbar temizliği hatası: $e');
    }

    return removedCount;
  }

  void _scheduleExpiredFirestoreCleanup(
    FirebaseFirestore fs,
    List<WasteReportModel> reports,
    DateTime now,
  ) {
    final expired = reports.where((r) => r.isExpiredAt(now)).toList();
    if (expired.isEmpty) return;

    Future<void>(() async {
      for (final report in expired) {
        try {
          await fs.collection('waste_reports').doc(report.id).delete();
        } catch (e) {
          debugPrint('[FirestoreService] Otomatik ihbar silme hatası (${report.id}): $e');
        }
      }
    });
  }

  /// Kullanıcının açtığı ihbarı siler
  Future<void> deleteReport(String reportId, {String? userId}) async {
    _ensureSeededReports();
    final index = _localReports.indexWhere((r) => r.id == reportId);
    String? ownerUid = userId;
    if (index != -1) {
      ownerUid ??= _localReports[index].userId;
      _localReports.removeAt(index);
    }

    if (ownerUid != null) {
      final existingUser = _localUsers[ownerUid];
      if (existingUser != null && existingUser.reportCount > 0) {
        _localUsers[ownerUid] = existingUser.copyWith(
          reportCount: existingUser.reportCount - 1,
        );
        _emitLocalUsers();
      }
    }
    _emitLocalReports();

    final fs = _firestore;
    if (fs == null) return;

    try {
      await fs.collection('waste_reports').doc(reportId).delete();
      if (ownerUid != null && ownerUid.isNotEmpty) {
        final userRef = fs.collection('users').doc(ownerUid);
        await fs.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          if (!snapshot.exists) return;
          final current = (snapshot.data()?['reportCount'] as num?)?.toInt() ?? 0;
          if (current > 0) {
            transaction.update(userRef, {'reportCount': current - 1});
          }
        });
      }
    } catch (e) {
      debugPrint('[FirestoreService] deleteReport Firestore senkronizasyon hatası: $e');
      rethrow;
    }
  }

  /// Yeni bir atık ihbarını 'waste_reports' koleksiyonuna ve yerel akışa ekler
  Future<void> createReport(WasteReportModel report) async {
    _ensureSeededReports();
    _localReports.insert(0, report);
    final existingUser = _localUsers[report.userId];
    if (existingUser != null) {
      _localUsers[report.userId] = existingUser.copyWith(
        reportCount: existingUser.reportCount + 1,
      );
    }
    _emitLocalReports();

    final fs = _firestore;
    if (fs == null) return;

    try {
      await fs.collection('waste_reports').doc(report.id).set(report.toJson());
      try {
        await fs.collection('users').doc(report.userId).set({
          'reportCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      } catch (userErr) {
        debugPrint('[FirestoreService] Kullanıcı reportCount güncellenemedi: $userErr');
      }
    } catch (e) {
      debugPrint('[FirestoreService] createReport Firestore senkronizasyon hatası: $e');
    }
  }

  /// Bir ihbarın durumunu 'resolved' (temizlendi) olarak günceller
  Future<void> resolveReport(
    String reportId, [
    String solverUid = 'demo_user_1',
  ]) async {
    _ensureSeededReports();
    final index = _localReports.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      _localReports[index] = _localReports[index].copyWith(
        status: 'resolved',
        resolvedBy: solverUid,
        resolvedAt: DateTime.now(),
      );
      _emitLocalReports();
    }

    final fs = _firestore;
    if (fs == null) return;

    try {
      await fs.collection('waste_reports').doc(reportId).update({
        'status': 'resolved',
        'resolvedBy': solverUid,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FirestoreService] resolveReport Firestore senkronizasyon hatası: $e');
    }
  }

  /// Bir ihbarı çözüldü olarak işaretler ve temizleyen kullanıcıya +15 ödül puanı ekler
  Future<void> markReportResolved(String reportId, String solverUid) async {
    await resolveReport(reportId, solverUid);
    await addEcoPoints(solverUid, 15);
  }
}
