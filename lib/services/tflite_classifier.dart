import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'tflite_runner.dart';

class ClassificationResult {
  final String label;
  final String wasteType;
  final double confidence;
  final String binColor;
  final String disposalTip;
  final bool isMock;

  const ClassificationResult({
    required this.label,
    required this.wasteType,
    required this.confidence,
    required this.binColor,
    required this.disposalTip,
    this.isMock = false,
  });
}

class TfliteClassifier {
  static const String _modelAssetPath = 'assets/models/waste_model.tflite';
  static const String _labelsAssetPath = 'assets/models/labels.txt';
  static const int inputSize = 224;

  final TfliteRunner _runner = TfliteRunner();
  List<String> _labels = [];
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;
  List<String> get labels => List.unmodifiable(_labels);

  /// Model (`assets/models/waste_model.tflite`) ve etiket (`assets/models/labels.txt`)
  /// dosyalarını yüklemeye çalışır. Dosyalar bulunamazsa veya Web platformundaysa
  /// uygulama çökmez; `_isModelLoaded = false` kalır ve akıllı mock fallback modu devreye girer.
  Future<void> init() async {
    try {
      final labelsRaw = await rootBundle.loadString(_labelsAssetPath);
      _labels = labelsRaw
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (_labels.isEmpty) {
        throw Exception('Etiket dosyası boş.');
      }

      final loaded = await _runner.loadModel(_modelAssetPath);
      if (!loaded) {
        throw Exception('Model yüklenemedi veya platform yerel TFLite desteklemiyor.');
      }

      _isModelLoaded = true;
      debugPrint(
        '[TfliteClassifier] Model ve ${_labels.length} etiket başarıyla yüklendi.',
      );
    } catch (e) {
      _isModelLoaded = false;
      _runner.dispose();
      _labels = const ['Plastik', 'Cam', 'Kağıt', 'Metal', 'Organik'];
      debugPrint(
        '[TfliteClassifier] Model veya etiket dosyası bulunamadı, fallback (mock) moduna geçildi: $e',
      );
    }
  }

  /// Ham görsel baytlarını 224x224 boyutuna ölçekler ve normalize edilmiş tensöre (`[1, 224, 224, 3]`) dönüştürür.
  Future<List<List<List<List<num>>>>> preprocessBytesToTensor(
    Uint8List imageBytes, {
    int targetWidth = inputSize,
    int targetHeight = inputSize,
    bool isQuantizedUint8 = false,
  }) async {
    final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image originalImage = frameInfo.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      originalImage,
      ui.Rect.fromLTWH(
        0,
        0,
        originalImage.width.toDouble(),
        originalImage.height.toDouble(),
      ),
      ui.Rect.fromLTWH(
        0,
        0,
        targetWidth.toDouble(),
        targetHeight.toDouble(),
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image resizedImage = await picture.toImage(targetWidth, targetHeight);
    final ByteData? byteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    originalImage.dispose();
    resizedImage.dispose();
    codec.dispose();

    if (byteData == null) {
      throw Exception('Görsel piksel verisi okunamadı.');
    }

    final Uint8List rgbaBytes = byteData.buffer.asUint8List();

    return List.generate(
      1,
      (_) => List.generate(
        targetHeight,
        (y) => List.generate(
          targetWidth,
          (x) {
            final int pixelIndex = (y * targetWidth + x) * 4;
            final int r = rgbaBytes[pixelIndex];
            final int g = rgbaBytes[pixelIndex + 1];
            final int b = rgbaBytes[pixelIndex + 2];

            if (isQuantizedUint8) {
              return <int>[r, g, b];
            }
            return <double>[r / 255.0, g / 255.0, b / 255.0];
          },
        ),
      ),
    );
  }

  /// `File` üzerinden 224x224 tensör üretir.
  Future<List<List<List<List<num>>>>> preprocessImageToTensor(
    File imageFile, {
    int targetWidth = inputSize,
    int targetHeight = inputSize,
    bool isQuantizedUint8 = false,
  }) async {
    final Uint8List imageBytes = await imageFile.readAsBytes();
    return preprocessBytesToTensor(
      imageBytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      isQuantizedUint8: isQuantizedUint8,
    );
  }

  /// Görsel baytlarını (mobil + Web uyumlu) sınıflandırır.
  Future<ClassificationResult> classifyBytes(Uint8List imageBytes) async {
    if (!_isModelLoaded || !_runner.isLoaded) {
      return _generateMockClassification();
    }

    try {
      final scores = await _runner.runImageClassification(
        ({
          required int width,
          required int height,
          required bool isQuantizedUint8,
        }) =>
            preprocessBytesToTensor(
          imageBytes,
          targetWidth: width,
          targetHeight: height,
          isQuantizedUint8: isQuantizedUint8,
        ),
        _labels.length,
      );

      int bestIndex = 0;
      double bestScore = -1.0;

      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > bestScore) {
          bestScore = scores[i];
          bestIndex = i;
        }
      }

      final String rawLabel = bestIndex < _labels.length
          ? _labels[bestIndex]
          : 'Plastik';

      final double normalizedConfidence = bestScore.clamp(0.0, 1.0);
      return _mapLabelToResult(rawLabel, normalizedConfidence);
    } catch (e) {
      debugPrint('[TfliteClassifier] Gerçek çıkarım hatası, fallback devreye girdi: $e');
      return _generateMockClassification();
    }
  }

  /// `File` üzerinden sınıflandırma yapar.
  Future<ClassificationResult> classifyImage(File imageFile) async {
    if (!_isModelLoaded || !_runner.isLoaded) {
      return _generateMockClassification();
    }

    try {
      final bytes = await imageFile.readAsBytes();
      return await classifyBytes(bytes);
    } catch (e) {
      debugPrint('[TfliteClassifier] Dosya okuma hatası, fallback devreye girdi: $e');
      return _generateMockClassification();
    }
  }

  Future<ClassificationResult> _generateMockClassification() async {
    await Future.delayed(const Duration(milliseconds: 850));

    const mockSamples = [
      ClassificationResult(
        label: 'Plastik Şişe',
        wasteType: 'Plastik',
        confidence: 0.924,
        binColor: 'Sarı Konteyner',
        disposalTip: 'Kapağını çıkarıp ezerek hacmini küçültün, sarı geri dönüşüm kutusuna atın.',
        isMock: true,
      ),
      ClassificationResult(
        label: 'Cam Kavanoz',
        wasteType: 'Cam',
        confidence: 0.896,
        binColor: 'Yeşil Konteyner',
        disposalTip: 'İçini sudan geçirip kırılmadan yeşil cam kumbarasına yerleştirin.',
        isMock: true,
      ),
      ClassificationResult(
        label: 'Karton Kutu',
        wasteType: 'Kağıt',
        confidence: 0.948,
        binColor: 'Mavi Konteyner',
        disposalTip: 'Katlayarak düzleştirin ve ıslanmamasına özen göstererek mavi kutuya atın.',
        isMock: true,
      ),
      ClassificationResult(
        label: 'Metal İçecek Kutusu',
        wasteType: 'Metal',
        confidence: 0.912,
        binColor: 'Gri Konteyner',
        disposalTip: 'İçinde sıvı kalmayacak şekilde boşaltıp ezerek gri metal kutusuna bırakın.',
        isMock: true,
      ),
    ];

    return mockSamples[Random().nextInt(mockSamples.length)];
  }

  ClassificationResult _mapLabelToResult(String rawLabel, double confidence) {
    final lower = rawLabel.toLowerCase();

    if (lower.contains('plastic') || lower.contains('plastik')) {
      return ClassificationResult(
        label: 'Plastik Şişe / Ambalaj',
        wasteType: 'Plastik',
        confidence: confidence,
        binColor: 'Sarı Konteyner',
        disposalTip: 'Kapağını çıkarıp ezerek sarı geri dönüşüm kutusuna atın.',
      );
    }
    if (lower.contains('paper') ||
        lower.contains('cardboard') ||
        lower.contains('kağıt') ||
        lower.contains('kagit') ||
        lower.contains('karton')) {
      return ClassificationResult(
        label: 'Kağıt / Karton',
        wasteType: 'Kağıt',
        confidence: confidence,
        binColor: 'Mavi Konteyner',
        disposalTip: 'Katlayarak düzleştirin, yağlı veya ıslak olmamasına dikkat ederek mavi kutuya atın.',
      );
    }
    if (lower.contains('glass') || lower.contains('cam')) {
      return ClassificationResult(
        label: 'Cam Şişe / Kavanoz',
        wasteType: 'Cam',
        confidence: confidence,
        binColor: 'Yeşil Konteyner',
        disposalTip: 'İçini durulayarak kırılmadan yeşil cam kumbarasına atın.',
      );
    }
    if (lower.contains('metal') || lower.contains('aluminum') || lower.contains('teneke')) {
      return ClassificationResult(
        label: 'Metal / Alüminyum Kutu',
        wasteType: 'Metal',
        confidence: confidence,
        binColor: 'Gri Konteyner',
        disposalTip: 'Boşaltıp hacmini küçülterek gri metal kutusuna atın.',
      );
    }

    return ClassificationResult(
      label: rawLabel,
      wasteType: 'Organik',
      confidence: confidence,
      binColor: 'Kahverengi Konteyner',
      disposalTip: 'Doğal kompost / organik atık kutusuna bırakın.',
    );
  }

  void dispose() {
    _runner.dispose();
    _isModelLoaded = false;
  }
}
