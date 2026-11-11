import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ecotrack/models/waste_report_model.dart';
import 'package:ecotrack/providers/auth_provider.dart';
import 'package:ecotrack/providers/map_provider.dart';
import 'package:ecotrack/providers/waste_provider.dart';
import 'package:ecotrack/services/firestore_service.dart';
import 'package:ecotrack/views/home/home_dashboard_view.dart';
import 'package:ecotrack/views/map/widgets/report_card_sheet.dart';
import 'package:ecotrack/views/navigation/main_shell_view.dart';
import 'package:ecotrack/views/report/create_report_view.dart';

class _EmptyFirestoreService extends FirestoreService {
  @override
  Stream<List<WasteReportModel>> getWasteReportsStream() =>
      Stream<List<WasteReportModel>>.value(const <WasteReportModel>[]);

  @override
  Future<List<WasteReportModel>> getWasteReports() async =>
      const <WasteReportModel>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FirestoreService.resetLocalDemoData();
  });

  group('HomeDashboardView Stage 5 Widget Testleri', () {
    testWidgets('AuthProvider olmadan varsayılan Çevre Gönüllüsü başlığını ve 0.00 kg CO2 gösterir',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeDashboardView(
            firestoreService: _EmptyFirestoreService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hoş Geldin, Çevre Gönüllüsü'), findsOneWidget);
      expect(find.text('Fidan'), findsOneWidget);
      expect(find.text('⭐ 0 Puan'), findsOneWidget);
      expect(find.text('0 Adet'), findsOneWidget);
      expect(find.text('0.00 kg CO₂'), findsOneWidget);
      expect(find.text('Günün Çevre İpucu'), findsOneWidget);
      expect(
        find.text('Henüz aktivite bulunmuyor, ilk atığını tara!'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Kullanıcı profili, 0.12 kg CO2 formülü, son aktiviteler ve detay kartı doğru render edilir',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: HomeDashboardView(
              firestoreService: FirestoreService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hoş Geldin, Emirhan Sapmaz'), findsOneWidget);
      expect(find.text('Doğa Dostu'), findsOneWidget);
      expect(find.text('⭐ 150 Puan'), findsOneWidget);
      expect(find.text('15 Adet'), findsOneWidget);
      // 15 * 0.12 = 1.80 kg CO2
      expect(find.text('1.80 kg CO₂'), findsOneWidget);
      expect(find.text('2 açılan • 1 çözülen'), findsOneWidget);
      expect(find.text('Sultanahmet Meydanı, Fatih / İstanbul'), findsOneWidget);
      expect(find.text('Karaköy Rıhtım, Beyoğlu / İstanbul'), findsOneWidget);

      // Son aktiviteye tıklanınca ReportCardSheet açılır
      await tester.ensureVisible(
        find.text('Sultanahmet Meydanı, Fatih / İstanbul'),
      );
      await tester.tap(find.text('Sultanahmet Meydanı, Fatih / İstanbul'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportCardSheet), findsOneWidget);
    });

    testWidgets('Hızlı erişim butonları doğru hedeflere yönlendirir',
        (WidgetTester tester) async {
      var scanTapped = false;
      var mapTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeDashboardView(
            firestoreService: FirestoreService(),
            onNavigateToScan: () => scanTapped = true,
            onNavigateToMap: () => mapTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Atık Tara'));
      expect(scanTapped, isTrue);

      await tester.tap(find.text('Atık Haritası'));
      expect(mapTapped, isTrue);

      await tester.tap(find.text('İhbar Bildir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CreateReportView), findsOneWidget);
    });

    testWidgets('MainShellView içinde Atık Tara butonu Tara sekmesine geçirir',
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
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Atık Tara'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atık Tara'));
      await tester.pumpAndSettle();

      expect(find.text('Atık Tara'), findsWidgets);
      expect(find.text('Galeri'), findsOneWidget);
    });

    testWidgets(
        'Son aktivite Haritada Göster butonu ilgili ihbarı harita odağına aktarır',
        (WidgetTester tester) async {
      WasteReportModel? focused;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeDashboardView(
            firestoreService: FirestoreService(),
            onShowReportOnMap: (report) => focused = report,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Haritada Göster').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Haritada Göster').first);
      await tester.pumpAndSettle();

      expect(focused, isNotNull);
      expect(focused!.addressText, equals('Sultanahmet Meydanı, Fatih / İstanbul'));
      expect(focused!.latitude, closeTo(41.0063, 0.001));
      expect(focused!.longitude, closeTo(28.9757, 0.001));
    });
  });
}
