import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ecotrack/core/utils/location_helper.dart';
import 'package:ecotrack/models/user_model.dart';
import 'package:ecotrack/providers/auth_provider.dart';
import 'package:ecotrack/providers/map_provider.dart';
import 'package:ecotrack/services/firestore_service.dart';
import 'package:ecotrack/services/storage_service.dart';
import 'package:ecotrack/views/report/create_report_view.dart';

class _DelayedStorageService extends StorageService {
  final Completer<String> uploadCompleter = Completer<String>();
  File? uploadedFile;

  @override
  Future<String> uploadReportImage(File imageFile) {
    uploadedFile = imageFile;
    return uploadCompleter.future;
  }
}

class _FailingStorageService extends StorageService {
  @override
  Future<String> uploadReportImage(File imageFile) async {
    throw Exception('Depolama sunucusuna ulaşılamadı.');
  }
}

Future<File> _createTempImageFile() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 12, 12),
    ui.Paint()..color = const Color(0xFF2E7D32),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(12, 12);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final file = File(
    '${Directory.systemTemp.path}/ecotrack_report_test_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FirestoreService.resetLocalDemoData();
  });

  group('StorageService Stage 4 Testleri', () {
    test('uploadReportImage mevcut olmayan dosya için anlamlı Exception fırlatır',
        () async {
      final storage = StorageService();
      final missingFile = File('${Directory.systemTemp.path}/non_existent_waste.jpg');

      await expectLater(
        () => storage.uploadReportImage(missingFile),
        throwsA(isA<Exception>()),
      );
    });

    test('uploadReportImage geçerli dosya ile demo/yerel modda URL döndürür',
        () async {
      final tempFile = await _createTempImageFile();
      try {
        final storage = StorageService();
        final url = await storage.uploadReportImage(tempFile);
        expect(url, isNotEmpty);
        expect(url, startsWith('https://'));
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });
  });

  group('CreateReportView Stage 4 Widget Testleri', () {
    testWidgets('Görsel veya konum eksikse SnackBar ile uyarır',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CreateReportView(
            locationFetcher: () async => const LocationResult(
              latitude: 41.0082,
              longitude: 28.9784,
              address: 'Fatih, İstanbul',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atık Fotoğrafı Yükle'), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Galeri'), findsOneWidget);
      expect(find.text('Fatih, İstanbul'), findsOneWidget);
      expect(find.text('Otomatik Kaldırma Bilgilendirmesi'), findsOneWidget);
      expect(
        find.text(
          'Temizlendi olarak işaretlenen atık ihbarları 12 saat sonra otomatik olarak kaldırılır.',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.tap(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.pumpAndSettle();

      expect(find.text('Lütfen atık fotoğrafı ekleyin.'), findsOneWidget);
    });

    testWidgets(
        'initialImage ve initialWasteType ile açılır, tüm kategorileri gösterir ve konumu yeniler',
        (WidgetTester tester) async {
      late File testImage;
      await tester.runAsync(() async {
        testImage = await _createTempImageFile();
      });

      var callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CreateReportView(
            initialImage: testImage,
            initialWasteType: 'Elektronik',
            locationFetcher: () async {
              callCount++;
              return LocationResult(
                latitude: 40.9900,
                longitude: 29.0200,
                address: callCount == 1 ? 'Kadıköy, İstanbul' : 'Üsküdar, İstanbul',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Görseli Değiştir'), findsOneWidget);
      expect(find.text('Kadıköy, İstanbul'), findsOneWidget);

      for (final category in [
        'Plastik',
        'Cam',
        'Kağıt',
        'Metal',
        'Organik',
        'Elektronik',
        'Diğer',
      ]) {
        expect(find.text(category), findsOneWidget);
      }

      final selectedChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Elektronik'),
      );
      expect(selectedChip.selected, isTrue);

      await tester.tap(find.text('Konumu Yenile'));
      await tester.pumpAndSettle();
      expect(find.text('Üsküdar, İstanbul'), findsOneWidget);

      // Konumu temizleyip doğrulama uyarısını test et
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.ensureVisible(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.tap(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.pumpAndSettle();

      expect(
        find.text('Konum veya adres bilgisi eksik. Lütfen konumu yenileyin.'),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      });
    });

    testWidgets(
        'Gönderim akışında yükleme overlay gösterir, uploadReportImage çağırır, +5 puan ekler ve pop yapar',
        (WidgetTester tester) async {
      late File testImage;
      await tester.runAsync(() async {
        testImage = await _createTempImageFile();
      });

      final firestore = FirestoreService();
      await firestore.createUserProfile(
        UserModel(
          uid: 'demo_user_1',
          fullName: 'Emirhan Test',
          email: 'test@ecotrack.app',
          ecoPoints: 20,
          createdAt: DateTime.now(),
        ),
      );
      final authProvider = AuthProvider(firestoreService: firestore);
      final delayedStorage = _DelayedStorageService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<MapProvider>(create: (_) => MapProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CreateReportView(
                          initialImage: testImage,
                          initialWasteType: 'Cam',
                          storageService: delayedStorage,
                          firestoreService: firestore,
                          locationFetcher: () async => const LocationResult(
                            latitude: 40.9911,
                            longitude: 29.0233,
                            address: 'Kadıköy, İstanbul',
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Formu Aç'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Formu Aç'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.tap(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.pump();

      // Yükleme süresince tam ekran overlay görünür
      expect(find.text('İhbar gönderiliyor...'), findsOneWidget);
      expect(delayedStorage.uploadedFile?.path, equals(testImage.path));

      // Yüklemeyi tamamla
      delayedStorage.uploadCompleter.complete(
        'https://firebasestorage.googleapis.com/v0/b/ecotrack/o/waste_reports%2Ftest.jpg',
      );
      await tester.pumpAndSettle();

      // "İhbarınız İçin Teşekkürler!" dialogu görünür
      expect(find.text('İhbarınız İçin Teşekkürler!'), findsOneWidget);
      expect(find.text('+5 Eco-Puan Kazandınız!'), findsOneWidget);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();

      // Ana sayfaya pop yapılmış olmalı ve başarı SnackBar'ı görünmeli
      expect(find.text('Formu Aç'), findsOneWidget);
      expect(
        find.text('İhbar başarıyla gönderildi! +5 Çevre Puanı kazandınız.'),
        findsOneWidget,
      );

      // FirestoreService üzerinden yeni ihbar ve +5 puan doğrula
      final reports = await firestore.getWasteReports();
      final created = reports.firstWhere(
        (r) => r.addressText == 'Kadıköy, İstanbul',
      );
      expect(created.wasteType, equals('Cam'));
      expect(created.status, equals('pending'));
      expect(
        created.imageUrl,
        equals(
          'https://firebasestorage.googleapis.com/v0/b/ecotrack/o/waste_reports%2Ftest.jpg',
        ),
      );
      expect(firestore.getLocalUser('demo_user_1')?.ecoPoints, equals(25));

      await tester.runAsync(() async {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      });
    });

    testWidgets('Storage hatasında SnackBar ile hata bildirir ve ekran kilitli kalmaz',
        (WidgetTester tester) async {
      late File testImage;
      await tester.runAsync(() async {
        testImage = await _createTempImageFile();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CreateReportView(
            initialImage: testImage,
            storageService: _FailingStorageService(),
            locationFetcher: () async => const LocationResult(
              latitude: 41.0082,
              longitude: 28.9784,
              address: 'Fatih, İstanbul',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.tap(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.pumpAndSettle();

      expect(find.text('İhbar gönderiliyor...'), findsNothing);
      expect(
        find.textContaining('Depolama sunucusuna ulaşılamadı.'),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      });
    });

    testWidgets(
        'Adres elle değiştirildiğinde kaydedilen ihbarın koordinatı adrese göre güncellenir',
        (WidgetTester tester) async {
      late File testImage;
      await tester.runAsync(() async {
        testImage = await _createTempImageFile();
      });

      final firestore = FirestoreService();
      await tester.pumpWidget(
        MaterialApp(
          home: CreateReportView(
            initialImage: testImage,
            firestoreService: firestore,
            locationFetcher: () async => const LocationResult(
              latitude: 41.0082,
              longitude: 28.9784,
              address: 'İstanbul, Türkiye',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Kadıköy Meydanı, İstanbul',
      );
      await tester.ensureVisible(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.tap(find.text('İhbarı Gönder (+5 Çevre Puanı)'));
      await tester.pumpAndSettle();

      final reports = await firestore.getWasteReports();
      final created = reports.firstWhere(
        (r) => r.addressText == 'Kadıköy Meydanı, İstanbul',
      );
      expect(created.latitude, closeTo(40.9903, 0.001));
      expect(created.longitude, closeTo(29.0290, 0.001));

      await tester.runAsync(() async {
        if (await testImage.exists()) {
          await testImage.delete();
        }
      });
    });
  });
}
