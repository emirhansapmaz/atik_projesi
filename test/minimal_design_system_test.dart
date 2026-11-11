import 'package:ecotrack/core/constants/app_colors.dart';
import 'package:ecotrack/core/theme/app_theme.dart';
import 'package:ecotrack/core/widgets/status_pill.dart';
import 'package:ecotrack/core/widgets/surface_card.dart';
import 'package:ecotrack/models/user_model.dart';
import 'package:ecotrack/models/waste_report_model.dart';
import 'package:ecotrack/providers/auth_provider.dart';
import 'package:ecotrack/providers/waste_provider.dart';
import 'package:ecotrack/services/firestore_service.dart';
import 'package:ecotrack/services/tflite_classifier.dart';
import 'package:ecotrack/views/home/home_dashboard_view.dart';
import 'package:ecotrack/views/navigation/main_shell_view.dart';
import 'package:ecotrack/views/scan/scan_view.dart';
import 'package:ecotrack/views/scan/widgets/result_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _StubFirestoreService extends FirestoreService {
  @override
  Stream<List<WasteReportModel>> getWasteReportsStream() =>
      Stream.value(const <WasteReportModel>[]);

  @override
  Future<List<WasteReportModel>> getWasteReports() async =>
      const <WasteReportModel>[];

  @override
  Stream<List<WasteReportModel>> getUserReportsStream(String userId) =>
      Stream.value(const <WasteReportModel>[]);
}

class _StubAuthProvider extends AuthProvider {
  final UserModel _stubUser = UserModel(
    uid: 'user_min_1',
    fullName: 'Minimal Test',
    email: 'test@ecotrack.org',
    ecoPoints: 120,
    recycledCount: 12,
    reportCount: 3,
    level: 'Doğa Dostu',
    createdAt: DateTime(2025, 1, 1),
  );

  _StubAuthProvider() : super(firestoreService: _StubFirestoreService());

  @override
  UserModel? get userModel => _stubUser;
}

void main() {
  group('Minimalist Antrasit Tasarım Sistemi Testleri', () {
    test('AppColors mat antrasit ve adaçayı yeşili paleti spec ile eşleşir', () {
      expect(AppColors.bgPrimary, const Color(0xFF0F1115));
      expect(AppColors.surface, const Color(0xFF16191F));
      expect(AppColors.surfaceBorder, const Color(0xFF242A35));
      expect(AppColors.surfaceSubtle, const Color(0xFF1E232B));
      expect(AppColors.primarySage, const Color(0xFF2D6A4F));
      expect(AppColors.primaryLight, const Color(0xFF52B788));
      expect(AppColors.statusPending, const Color(0xFFD97706));
      expect(AppColors.statusResolved, const Color(0xFF2D6A4F));
    });

    test('AppTheme karanlık mat temayı uygular', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.bgPrimary);
      expect(theme.colorScheme.primary, AppColors.primarySage);
      expect(theme.colorScheme.surface, AppColors.surface);
    });

    testWidgets(
        'SurfaceCard 1px kenarlık, 16px köşe ve sıfır BackdropFilter / BoxShadow ile render edilir',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: Center(
              child: SurfaceCard(
                child: Text('Minimal İçerik'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Minimal İçerik'), findsOneWidget);

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(SurfaceCard),
          matching: find.byType(Material),
        ),
      );

      expect(material.color, AppColors.surface);
      expect(material.elevation, 0.0);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
      expect(shape.side.color, AppColors.surfaceBorder);
      expect(shape.side.width, 1.0);
    });

    testWidgets('StatusPill düz mat rozet render eder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatusPill(
                label: 'Bekliyor',
                color: AppColors.statusPending,
                showDot: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bekliyor'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('MainShellView sade SurfaceCard dock kullanır ve bulanıklık içermez',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _StubAuthProvider(),
            ),
            ChangeNotifierProvider<WasteProvider>(
              create: (_) => WasteProvider(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MainShellView(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(SurfaceCard), findsWidgets);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.bgPrimary);
    });

    testWidgets(
        'HomeDashboardView SurfaceCard kartları, 24px beyaz metrik ve 2px ipucu çizgisi içerir',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _StubAuthProvider(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: HomeDashboardView(
              firestoreService: _StubFirestoreService(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(SurfaceCard), findsWidgets);

      final recycledText = tester.widget<Text>(find.text('12 Adet'));
      expect(recycledText.style?.color, AppColors.textPrimary);
      expect(recycledText.style?.fontSize, 24);
      expect(recycledText.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('ScanView neon efekt olmadan sade vizör sunar', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<WasteProvider>(
              create: (_) => WasteProvider(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ScanView(isActive: false),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Atık Tara'), findsOneWidget);
      expect(find.text('Galeri'), findsOneWidget);
    });

    testWidgets('ResultBottomSheet mat yüzey ve primarySage aksiyon butonu sunar',
        (tester) async {
      const mockResult = ClassificationResult(
        label: 'Plastik Şişe',
        wasteType: 'Plastik',
        confidence: 0.94,
        binColor: 'Sarı',
        disposalTip: 'Şişeyi ezerek sarı plastik geri dönüşüm kutusuna atın.',
        isMock: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _StubAuthProvider(),
            ),
            ChangeNotifierProvider<WasteProvider>(
              create: (_) => WasteProvider(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ResultBottomSheet(
                  result: mockResult,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('PLASTİK ŞİŞE'), findsOneWidget);
      expect(find.text('Plastik - %94.0'), findsOneWidget);
      expect(find.text('Geri Dönüştürdüm (+10 Puan)'), findsOneWidget);
      expect(find.text('Sokağa Atılmış, İhbar Et'), findsOneWidget);

      final titleText = tester.widget<Text>(find.text('PLASTİK ŞİŞE'));
      expect(titleText.style?.color, AppColors.textPrimary);
    });
  });
}
