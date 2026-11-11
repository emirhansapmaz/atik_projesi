import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/tflite_classifier.dart';

class WasteProvider extends ChangeNotifier {
  final TfliteClassifier _classifier;
  final FirestoreService _firestoreService;

  File? _scannedImage;
  Uint8List? _scannedImageBytes;
  ClassificationResult? _lastResult;
  bool _isAnalyzing = false;
  String? _errorMessage;

  WasteProvider({
    TfliteClassifier? classifier,
    FirestoreService? firestoreService,
  })  : _classifier = classifier ?? TfliteClassifier(),
        _firestoreService = firestoreService ?? FirestoreService();

  File? get scannedImage => _scannedImage;
  Uint8List? get scannedImageBytes => _scannedImageBytes;
  ClassificationResult? get lastResult => _lastResult;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;

  /// Görseli `File` üzerinden TFLite modeli (veya fallback) ile sınıflandırır
  Future<ClassificationResult?> analyzeImage(File imageFile) async {
    _scannedImage = imageFile;
    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _classifier.classifyImage(imageFile);
      _lastResult = result;
      _isAnalyzing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Atık analizi başarısız oldu: $e';
      _isAnalyzing = false;
      notifyListeners();
      return null;
    }
  }

  /// Görseli bayt dizisi (`Uint8List`) üzerinden sınıflandırır (Mobil + Web uyumlu)
  Future<ClassificationResult?> analyzeBytes(Uint8List imageBytes, {File? file}) async {
    _scannedImage = file;
    _scannedImageBytes = imageBytes;
    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _classifier.classifyBytes(imageBytes);
      _lastResult = result;
      _isAnalyzing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Atık analizi başarısız oldu: $e';
      _isAnalyzing = false;
      notifyListeners();
      return null;
    }
  }

  /// "Geri Dönüştürdüm" butonu tıklandığında puan ekler
  Future<bool> recordRecycle(String userId) async {
    try {
      await _firestoreService.addEcoPoints(userId, 10, isRecycle: true);
      return true;
    } catch (e) {
      _errorMessage = 'Puan kaydedilemedi: $e';
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _scannedImage = null;
    _scannedImageBytes = null;
    _lastResult = null;
    _isAnalyzing = false;
    _errorMessage = null;
    notifyListeners();
  }
}
