import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/waste_report_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- KULLANICI İŞLEMLERİ ---

  Future<void> createUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Stream<UserModel?> streamUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  Future<void> addEcoPoints(String uid, int points, {bool isRecycle = false}) async {
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      final currentPoints = snapshot.data()?['ecoPoints'] ?? 0;
      final currentRecycled = snapshot.data()?['recycledCount'] ?? 0;
      final newPoints = currentPoints + points;

      String newLevel = 'Başlangıç';
      if (newPoints >= 200) {
        newLevel = 'Çevre Kahramanı';
      } else if (newPoints >= 80) {
        newLevel = 'Doğa Dostu';
      }

      transaction.update(userRef, {
        'ecoPoints': newPoints,
        'level': newLevel,
        if (isRecycle) 'recycledCount': currentRecycled + 1,
      });
    });
  }

  // --- ATIK RAPORLARI (İHBAR) İŞLEMLERİ ---

  Stream<List<WasteReportModel>> streamWasteReports() {
    return _firestore
        .collection('waste_reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => WasteReportModel.fromFirestore(doc)).toList());
  }

  Future<void> createReport(WasteReportModel report) async {
    await _firestore.collection('waste_reports').doc(report.id).set(report.toMap());

    // Kullanıcının ihbar sayısını ve puanını artır
    await _firestore.collection('users').doc(report.userId).update({
      'reportCount': FieldValue.increment(1),
      'ecoPoints': FieldValue.increment(15), // İhbar açma ödülü
    });
  }

  Future<void> markReportResolved(String reportId, String solverUid) async {
    await _firestore.collection('waste_reports').doc(reportId).update({
      'status': 'resolved',
      'resolvedBy': solverUid,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    // Temizleyen kullanıcıya ödül puanı
    await addEcoPoints(solverUid, 25);
  }
}