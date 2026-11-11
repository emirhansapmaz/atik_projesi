import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage? _customStorage;
  final Uuid _uuid = const Uuid();

  static const String _fallbackImageUrl =
      'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=600&q=80';

  StorageService({FirebaseStorage? storage}) : _customStorage = storage;

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

  FirebaseStorage? get _storage {
    if (_customStorage != null) return _customStorage;
    if (isFirebaseAvailable) {
      try {
        return FirebaseStorage.instance;
      } catch (e) {
        debugPrint('[StorageService] FirebaseStorage instance alınamadı: $e');
      }
    }
    return null;
  }

  /// Cihazdaki [imageFile] dosyasını `"waste_reports/{uuid}.jpg"` yoluna yükler
  /// ve indirme bağlantısını (downloadUrl) döndürür.
  Future<String> uploadReportImage(File imageFile) async {
    if (!kIsWeb && !imageFile.existsSync()) {
      throw Exception('Yüklenecek görsel dosyası bulunamadı.');
    }

    return _executeUpload(
      uploadAction: (ref, metadata) => ref.putFile(imageFile, metadata),
    );
  }

  /// Web veya bellek içi bayt dizisi (`Uint8List`) üzerinden görsel yükler.
  Future<String> uploadReportBytes(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw Exception('Yüklenecek görsel verisi boş.');
    }

    return _executeUpload(
      uploadAction: (ref, metadata) => ref.putData(imageBytes, metadata),
    );
  }

  /// Ortak Firebase Storage yükleme ve hata yakalama yardımcısı
  Future<String> _executeUpload({
    required UploadTask Function(Reference ref, SettableMetadata metadata) uploadAction,
  }) async {
    final storage = _storage;
    if (storage == null) {
      debugPrint(
        '[StorageService] Firebase Storage etkin değil, yerel demo görsel URL\'si döndürülüyor.',
      );
      return _fallbackImageUrl;
    }

    try {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = storage.ref().child('waste_reports').child(fileName);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final snapshot = await uploadAction(ref, metadata);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isEmpty) {
        throw Exception('Yüklenen dosyanın indirme bağlantısı boş döndü.');
      }
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception(
        'Firebase Storage yükleme hatası (${e.code}): ${e.message ?? 'Bilinmeyen hata'}',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Görsel yüklenirken beklenmeyen bir hata oluştu: $e');
    }
  }

  /// Profil fotoğrafını `"profile_photos/{userId}.jpg"` yoluna yükler
  Future<String> uploadProfileImage(File imageFile, {required String userId}) async {
    if (!kIsWeb && !imageFile.existsSync()) {
      throw Exception('Yüklenecek profil fotoğrafı dosyası bulunamadı.');
    }

    final storage = _storage;
    if (storage == null) {
      debugPrint(
        '[StorageService] Firebase Storage etkin değil, yerel demo profil fotoğrafı URL\'si döndürülüyor.',
      );
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
    }

    try {
      final ref = storage.ref().child('profile_photos').child('$userId.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final snapshot = await ref.putFile(imageFile, metadata);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isEmpty) {
        throw Exception('Yüklenen profil fotoğrafının indirme bağlantısı boş döndü.');
      }
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception(
        'Profil fotoğrafı yükleme hatası (${e.code}): ${e.message ?? 'Bilinmeyen hata'}',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Profil fotoğrafı yüklenirken beklenmeyen bir hata oluştu: $e');
    }
  }

  /// Web veya bellek içi bayt dizisi üzerinden profil fotoğrafı yükler
  Future<String> uploadProfileBytes(Uint8List imageBytes, {required String userId}) async {
    if (imageBytes.isEmpty) {
      throw Exception('Yüklenecek profil fotoğrafı verisi boş.');
    }

    final storage = _storage;
    if (storage == null) {
      debugPrint(
        '[StorageService] Firebase Storage etkin değil, yerel demo profil fotoğrafı URL\'si döndürülüyor.',
      );
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
    }

    try {
      final ref = storage.ref().child('profile_photos').child('$userId.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final snapshot = await ref.putData(imageBytes, metadata);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isEmpty) {
        throw Exception('Yüklenen profil fotoğrafının indirme bağlantısı boş döndü.');
      }
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception(
        'Profil fotoğrafı yükleme hatası (${e.code}): ${e.message ?? 'Bilinmeyen hata'}',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Profil fotoğrafı yüklenirken beklenmeyen bir hata oluştu: $e');
    }
  }

  /// Önceki sürümlerle uyumluluk için yönlendirme metodları
  Future<String> uploadWasteImage(File imageFile) => uploadReportImage(imageFile);

  Future<String> uploadWasteBytes(Uint8List imageBytes) =>
      uploadReportBytes(imageBytes);
}
