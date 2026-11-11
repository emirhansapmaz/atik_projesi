import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ecotrack/core/utils/location_helper.dart';
import 'package:ecotrack/models/user_model.dart';
import 'package:ecotrack/models/waste_report_model.dart';
import 'package:ecotrack/providers/auth_provider.dart';
import 'package:ecotrack/providers/map_provider.dart';
import 'package:ecotrack/services/firestore_service.dart';
import 'package:ecotrack/views/map/waste_map_view.dart';
import 'package:ecotrack/views/map/widgets/report_card_sheet.dart';
import 'package:ecotrack/views/report/create_report_view.dart';

// Testlerde ağ isteği atmayan 1x1 şeffaf PNG tile sağlayıcı
final Uint8List _transparentPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class _FakeTileProvider extends TileProvider {
  _FakeTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPngBytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FirestoreService.resetLocalDemoData();
  });

  group('FirestoreService Stage 3 Akış Testleri', () {
    test('getWasteReportsStream başlangıç verilerini yayınlar ve resolveReport ile günceller',
        () async {
      final service = FirestoreService();
      await service.createUserProfile(
        UserModel(
          uid: 'demo_user_1',
          fullName: 'Test Kullanıcısı',
          email: 'test@ecotrack.app',
          createdAt: DateTime.now(),
        ),
      );

      final emissions = <List<WasteReportModel>>[];
      final sub = service.getWasteReportsStream().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(emissions, isNotEmpty);
      expect(
        emissions.last.any((r) => r.id == 'sample_1' && r.status == 'pending'),
        isTrue,
      );

      await service.resolveReport('sample_1', 'demo_user_1');
      await service.addEcoPoints('demo_user_1', 15);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final resolvedSample =
          emissions.last.firstWhere((r) => r.id == 'sample_1');
      expect(resolvedSample.status, equals('resolved'));
      expect(resolvedSample.resolvedBy, equals('demo_user_1'));
      expect(service.getLocalUser('demo_user_1')?.ecoPoints, equals(15));

      await sub.cancel();
    });

    test(
        'Temizlenen ihbarlar 12 saat dolunca otomatik kaldırılır ve deleteReport ihbarı siler',
        () async {
      final service = FirestoreService();
      final now = DateTime.now();

      final expiredReport = WasteReportModel(
        id: 'expired_resolved_1',
        userId: 'demo_user_1',
        userName: 'Test',
        wasteType: 'Cam',
        confidence: 0.90,
        description: '13 saat önce temizlenen ihbar',
        imageUrl: '',
        latitude: 41.01,
        longitude: 28.98,
        addressText: 'Beşiktaş, İstanbul',
        status: 'resolved',
        resolvedBy: 'solver_x',
        createdAt: now.subtract(const Duration(hours: 15)),
        resolvedAt: now.subtract(const Duration(hours: 13)),
      );
      final recentResolved = WasteReportModel(
        id: 'recent_resolved_1',
        userId: 'demo_user_1',
        userName: 'Test',
        wasteType: 'Plastik',
        confidence: 0.88,
        description: '3 saat önce temizlenen ihbar',
        imageUrl: '',
        latitude: 41.02,
        longitude: 28.99,
        addressText: 'Şişli, İstanbul',
        status: 'resolved',
        resolvedBy: 'solver_x',
        createdAt: now.subtract(const Duration(hours: 4)),
        resolvedAt: now.subtract(const Duration(hours: 3)),
      );

      await service.createReport(expiredReport);
      await service.createReport(recentResolved);

      final activeReports = await service.getWasteReports();
      expect(activeReports.any((r) => r.id == 'expired_resolved_1'), isFalse);
      expect(activeReports.any((r) => r.id == 'recent_resolved_1'), isTrue);

      // Gelecek zaman simülasyonuyla 12 saati aşan temizlenmiş ihbarı temizle
      final purgedCount = await service.purgeExpiredReports(
        now: now.add(const Duration(hours: 10)),
      );
      expect(purgedCount, greaterThanOrEqualTo(1));
      final afterPurge = await service.getWasteReports();
      expect(afterPurge.any((r) => r.id == 'recent_resolved_1'), isFalse);

      // Kullanıcının kendi ihbarını deleteReport ile silmesi
      final ownPending = WasteReportModel(
        id: 'own_pending_delete_1',
        userId: 'demo_user_1',
        userName: 'Test',
        wasteType: 'Metal',
        confidence: 0.92,
        description: 'Silinecek test ihbarı',
        imageUrl: '',
        latitude: 41.00,
        longitude: 28.97,
        addressText: 'Fatih, İstanbul',
        status: 'pending',
        createdAt: now,
      );
      await service.createReport(ownPending);
      expect((await service.getWasteReports()).any((r) => r.id == ownPending.id), isTrue);

      await service.deleteReport(ownPending.id, userId: 'demo_user_1');
      final afterDelete = await service.getWasteReports();
      expect(afterDelete.any((r) => r.id == ownPending.id), isFalse);
    });
  });

  group('WasteMapView ve ReportCardSheet Widget Testleri', () {
    Widget buildTestHost({
      Future<LocationResult> Function()? locationFetcher,
      AuthProvider? authProvider,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => authProvider ?? AuthProvider(),
          ),
          ChangeNotifierProvider<MapProvider>(
            create: (_) => MapProvider(),
          ),
        ],
        child: MaterialApp(
          home: WasteMapView(
            firestoreService: FirestoreService(),
            tileProvider: _FakeTileProvider(),
            locationFetcher: locationFetcher ??
                () async => const LocationResult(
                      latitude: LocationHelper.defaultLatitude,
                      longitude: LocationHelper.defaultLongitude,
                      address: LocationHelper.defaultAddress,
                    ),
          ),
        ),
      );
    }

    testWidgets('OpenStreetMap TileLayer, karanlık filtre, yakınlaştırma, Konumuma Git ve İhbar Ekle FAB render eder',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestHost());
      await tester.pumpAndSettle();

      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(
        tileLayer.urlTemplate,
        equals('https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
      );
      expect(tileLayer.subdomains, isEmpty);
      expect(
        tileLayer.tileProvider.headers['User-Agent'],
        contains('com.ecotrack.app'),
      );
      expect(
        find.ancestor(
          of: find.byType(TileLayer),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byTooltip('Yakınlaştır'), findsOneWidget);
      expect(find.byTooltip('Uzaklaştır'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.text('İhbar Ekle'), findsOneWidget);
      expect(find.text('Tümü (3)'), findsOneWidget);
      expect(find.text('Bekliyor (2)'), findsOneWidget);
      expect(find.text('Temizlendi (1)'), findsOneWidget);

      await tester.tap(find.byTooltip('Yakınlaştır'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Uzaklaştır'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Marker tıklanınca ReportCardSheet açılır ve Temizlendi Olarak İşaretle (+15 Puan) çalışır',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestHost());
      await tester.pumpAndSettle();

      final pendingMarkerFinder = find.byKey(const ValueKey('marker_sample_1'));
      expect(pendingMarkerFinder, findsOneWidget);

      await tester.tap(pendingMarkerFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ReportCardSheet), findsOneWidget);
      expect(find.text('Plastik'), findsOneWidget);
      expect(find.text('Bekliyor'), findsOneWidget);
      expect(find.text('%94.0 Güven'), findsNothing);
      expect(find.text('Sultanahmet Meydanı, Fatih / İstanbul'), findsOneWidget);
      expect(
        find.text('Temizlendi Olarak İşaretle (+15 Puan)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Temizlendi Olarak İşaretle (+15 Puan)'));
      await tester.pumpAndSettle();

      expect(find.byType(ReportCardSheet), findsNothing);
      expect(
        find.text('İhbar temizlendi olarak işaretlendi! +15 Eco-Puan kazandınız.'),
        findsOneWidget,
      );
      expect(find.text('Bekliyor (1)'), findsOneWidget);
      expect(find.text('Temizlendi (2)'), findsOneWidget);
      expect(
        FirestoreService().getLocalUser('demo_user_1')?.ecoPoints,
        equals(15),
      );
    });

    testWidgets('Konum izni reddedildiğinde varsayılan İstanbul merkezi ile Konumuma Git çalışır',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestHost());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();

      expect(
        find.text('Konum izni alınamadı, varsayılan İstanbul merkezi gösteriliyor.'),
        findsOneWidget,
      );
    });

    testWidgets('İhbar Ekle FAB butonuna tıklanınca CreateReportView ekranına geçer',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestHost());
      await tester.pumpAndSettle();

      await tester.tap(find.text('İhbar Ekle'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CreateReportView), findsOneWidget);
      expect(find.text('Saha İhbarı Oluştur'), findsOneWidget);
    });

    testWidgets('Boş görsel URL için ReportCardSheet gri fallback kartı gösterir',
        (WidgetTester tester) async {
      final reportWithoutPhoto = WasteReportModel(
        id: 'empty_photo_report',
        userId: 'u_99',
        userName: 'Ece Aydın',
        wasteType: 'Kağıt',
        confidence: 0.87,
        description: 'Karton kutular bırakılmış.',
        imageUrl: '',
        latitude: 41.01,
        longitude: 28.98,
        addressText: 'Beşiktaş / İstanbul',
        status: 'resolved',
        createdAt: DateTime(2026, 11, 10, 14, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportCardSheet(report: reportWithoutPhoto),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Görsel yüklenemedi'), findsOneWidget);
      expect(find.text('Temizlendi'), findsOneWidget);
      expect(find.text('Bu bölgedeki atık temizlenmiştir.'), findsOneWidget);
      expect(
        find.text('Temizlenen ihbarlar 12 saat sonra otomatik kaldırılır.'),
        findsOneWidget,
      );
      expect(find.text('İhbarı Sil'), findsNothing);
    });

    testWidgets(
        'Kullanıcı kendi ihbarının detay kartında İhbarı Sil butonunu görür ve onaylayarak silebilir',
        (WidgetTester tester) async {
      final service = FirestoreService();
      final authProvider = AuthProvider(firestoreService: service);
      final ownReport = WasteReportModel(
        id: 'own_sheet_delete_1',
        userId: 'demo_user_1',
        userName: 'Emirhan Sapmaz',
        wasteType: 'Plastik',
        confidence: 0.93,
        description: 'Kendi oluşturduğum ihbar.',
        imageUrl: '',
        latitude: 41.0082,
        longitude: 28.9784,
        addressText: 'Karaköy, İstanbul',
        status: 'pending',
        createdAt: DateTime.now(),
      );
      await service.createReport(ownReport);

      var deletedCallbackCalled = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ReportCardSheet(
                        report: ownReport,
                        firestoreService: service,
                        onDeleted: () => deletedCallbackCalled = true,
                      ),
                    );
                  },
                  child: const Text('Detayı Aç'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Detayı Aç'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('İhbarı Sil'));
      expect(find.text('İhbarı Sil'), findsOneWidget);
      await tester.tap(find.text('İhbarı Sil'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bu atık ihbarını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sil'));
      await tester.pumpAndSettle();

      expect(deletedCallbackCalled, isTrue);
      expect(find.text('İhbarınız silindi.'), findsOneWidget);
      final remaining = await service.getWasteReports();
      expect(remaining.any((r) => r.id == ownReport.id), isFalse);
      expect(authProvider.userModel?.reportCount, 1);
    });

    testWidgets(
        'focusedReport verildiğinde harita ilgili ihbarın gerçek koordinatına odaklanır',
        (WidgetTester tester) async {
      final kadikoyReport = WasteReportModel(
        id: 'kadikoy_focus_1',
        userId: 'u_kadikoy',
        userName: 'Deniz',
        wasteType: 'Plastik',
        confidence: 0.91,
        description: 'İskele yanı şişeler',
        imageUrl: '',
        latitude: 40.9903,
        longitude: 29.0290,
        addressText: 'Kadıköy İskelesi, İstanbul',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WasteMapView(
            firestoreService: FirestoreService(),
            tileProvider: _FakeTileProvider(),
            focusedReport: kadikoyReport,
            focusRequestKey: 1,
            locationFetcher: () async => const LocationResult(
              latitude: 41.0082,
              longitude: 28.9784,
              address: 'İstanbul, Türkiye',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mapWidget = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(mapWidget.options.initialCenter.latitude, closeTo(40.9903, 0.0001));
      expect(mapWidget.options.initialCenter.longitude, closeTo(29.0290, 0.0001));
      expect(mapWidget.options.initialZoom, equals(16.0));
      expect(find.text('Kadıköy İskelesi, İstanbul'), findsOneWidget);
      expect(find.byKey(const ValueKey('marker_kadikoy_focus_1')), findsOneWidget);
    });
  });
}
