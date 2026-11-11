import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ecotrack/providers/auth_provider.dart';
import 'package:ecotrack/providers/map_provider.dart';
import 'package:ecotrack/providers/waste_provider.dart';
import 'package:ecotrack/services/tflite_classifier.dart';
import 'package:ecotrack/views/navigation/main_shell_view.dart';
import 'package:ecotrack/views/report/create_report_view.dart';
import 'package:ecotrack/views/scan/widgets/result_bottom_sheet.dart';

Future<File> _createTempTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 10, 10),
    ui.Paint()..color = const Color(0xFF2E7D32),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(10, 10);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final file = File(
    '${Directory.systemTemp.path}/ecotrack_test_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TfliteClassifier Testleri', () {
    test('Model olmadığında çökmeden mock fallback sonucu üretir', () async {
      final classifier = TfliteClassifier();
      await classifier.init();

      expect(classifier.isModelLoaded, isFalse);

      final tempFile = File('${Directory.systemTemp.path}/dummy_waste.jpg');
      final result = await classifier.classifyImage(tempFile);

      expect(result.isMock, isTrue);
      expect(result.wasteType, isNotEmpty);
      expect(result.binColor, isNotEmpty);
      expect(result.disposalTip, isNotEmpty);
      expect(result.confidence, inInclusiveRange(0.5, 1.0));
    });

    testWidgets('Görseli 224x224 boyutuna normalize edip [1, 224, 224, 3] tensörüne çevirir',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        final testImage = await _createTempTestImage();
        try {
          final classifier = TfliteClassifier();
          final floatTensor = await classifier.preprocessImageToTensor(testImage);

          expect(floatTensor.length, 1);
          expect(floatTensor[0].length, 224);
          expect(floatTensor[0][0].length, 224);
          expect(floatTensor[0][0][0].length, 3);

          final rgb = floatTensor[0][0][0];
          for (final channel in rgb) {
            expect(channel, inInclusiveRange(0.0, 1.0));
          }

          final uint8Tensor = await classifier.preprocessImageToTensor(
            testImage,
            isQuantizedUint8: true,
          );
          final uint8Rgb = uint8Tensor[0][0][0];
          expect(uint8Rgb.every((v) => v is int && v >= 0 && v <= 255), isTrue);
        } finally {
          if (await testImage.exists()) {
            await testImage.delete();
          }
        }
      });
    });
  });

  group('ResultBottomSheet ve ScanView Testleri', () {
    testWidgets('ResultBottomSheet geri dönüşümde +10 puan ekler ve SnackBar gösterir',
        (WidgetTester tester) async {
      late File testImage;
      await tester.runAsync(() async {
        testImage = await _createTempTestImage();
      });

      final authProvider = AuthProvider();
      final initialPoints = authProvider.userModel!.ecoPoints;

      const sampleResult = ClassificationResult(
        label: 'Plastik Şişe',
        wasteType: 'Plastik',
        confidence: 0.934,
        binColor: 'Sarı Konteyner',
        disposalTip: 'Kapağını çıkarıp ezerek sarı kutuya atın.',
        isMock: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => WasteProvider()),
            ChangeNotifierProvider(create: (_) => MapProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ResultBottomSheet(
                        imageFile: testImage,
                        result: sampleResult,
                      ),
                    );
                  },
                  child: const Text('Sonucu Aç'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sonucu Aç'));
      await tester.pumpAndSettle();

      expect(find.text('Plastik - %93.4'), findsOneWidget);
      expect(find.text('Sarı Geri Dönüşüm Kutusu (Plastik)'), findsOneWidget);
      expect(find.text('Geri Dönüştürdüm (+10 Puan)'), findsOneWidget);
      expect(find.text('Sokağa Atılmış, İhbar Et'), findsOneWidget);

      await tester.tap(find.text('Geri Dönüştürdüm (+10 Puan)'));
      await tester.pumpAndSettle();

      expect(authProvider.userModel!.ecoPoints, initialPoints + 10);
      expect(find.text('Harika! Geri dönüşüm için +10 Eco-Puan kazandınız.'), findsOneWidget);

      await tester.runAsync(() async {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      });
    });

    testWidgets('Sokağa Atılmış, İhbar Et butonu CreateReportView ekranına yönlendirir',
        (WidgetTester tester) async {
      late File testImage;
      await tester.runAsync(() async {
        testImage = await _createTempTestImage();
      });

      const sampleResult = ClassificationResult(
        label: 'Cam Kavanoz',
        wasteType: 'Cam',
        confidence: 0.896,
        binColor: 'Yeşil Konteyner',
        disposalTip: 'İçini durulayın.',
        isMock: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => WasteProvider()),
            ChangeNotifierProvider(create: (_) => MapProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ResultBottomSheet(
                        imageFile: testImage,
                        result: sampleResult,
                      ),
                    );
                  },
                  child: const Text('Sonucu Aç'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sonucu Aç'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sokağa Atılmış, İhbar Et'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CreateReportView), findsOneWidget);
      expect(find.text('Saha İhbarı Oluştur'), findsOneWidget);

      await tester.runAsync(() async {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      });
    });

    testWidgets('EcoTrackApp Tara sekmesine geçildiğinde güvenli olarak yüklenir',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => WasteProvider()),
            ChangeNotifierProvider(create: (_) => MapProvider()),
          ],
          child: const MaterialApp(home: MainShellView()),
        ),
      );
      await tester.tap(find.text('Tara'));
      await tester.pumpAndSettle();

      expect(find.text('Atık Tara'), findsOneWidget);
      expect(find.text('Galeri'), findsOneWidget);
    });
  });
}
