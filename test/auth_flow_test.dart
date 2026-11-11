import 'package:ecotrack/core/theme/app_theme.dart';
import 'package:ecotrack/core/widgets/ecotrack_logo.dart';
import 'package:ecotrack/models/waste_report_model.dart';
import 'package:ecotrack/providers/auth_provider.dart';
import 'package:ecotrack/providers/map_provider.dart';
import 'package:ecotrack/providers/waste_provider.dart';
import 'package:ecotrack/services/firestore_service.dart';
import 'package:ecotrack/views/auth/forgot_password_view.dart';
import 'package:ecotrack/views/auth/login_view.dart';
import 'package:ecotrack/views/auth/register_view.dart';
import 'package:ecotrack/views/auth/splash_view.dart';
import 'package:ecotrack/views/home/home_dashboard_view.dart';
import 'package:ecotrack/views/navigation/main_shell_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _EmptyFirestoreService extends FirestoreService {
  @override
  Stream<List<WasteReportModel>> getWasteReportsStream() =>
      Stream<List<WasteReportModel>>.value(const <WasteReportModel>[]);

  @override
  Future<List<WasteReportModel>> getWasteReports() async =>
      const <WasteReportModel>[];
}

Widget _wrapWithProviders({
  required AuthProvider authProvider,
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<WasteProvider>(create: (_) => WasteProvider()),
      ChangeNotifierProvider<MapProvider>(create: (_) => MapProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: home,
    ),
  );
}

void main() {
  setUp(() {
    FirestoreService.resetLocalDemoData();
    AuthProvider.resetLocalAccounts();
  });

  group('Kimlik Doğrulama & Logo Akışı Testleri', () {
    testWidgets(
        'HomeDashboardView üst çubuğunda EcoTrack yazısı yerine EcoTrackLogo gösterilir',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          authProvider: AuthProvider(),
          home: HomeDashboardView(firestoreService: _EmptyFirestoreService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(EcoTrackLogo),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('EcoTrack'),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'SplashView logoyu gösterir ve oturum yoksa LoginView ekranına yönlenir',
        (tester) async {
      final authProvider = AuthProvider();
      expect(authProvider.hasActiveSession, isFalse);

      await tester.pumpWidget(
        _wrapWithProviders(
          authProvider: authProvider,
          home: const SplashView(splashDuration: Duration(milliseconds: 200)),
        ),
      );

      expect(find.byType(EcoTrackLogo), findsOneWidget);
      expect(find.text('EcoTrack'), findsOneWidget);
      expect(find.text('Akıllı Atık Tespit ve Takip'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('SplashView aktif oturum varsa doğrudan MainShellView açar',
        (tester) async {
      final authProvider = AuthProvider();
      await authProvider.continueAsDemo();
      expect(authProvider.hasActiveSession, isTrue);

      await tester.pumpWidget(
        _wrapWithProviders(
          authProvider: authProvider,
          home: const SplashView(splashDuration: Duration(milliseconds: 100)),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byType(MainShellView), findsOneWidget);
    });

    testWidgets(
        'LoginView form doğrulaması yapar ve e-posta/şifre ile giriş sağlar',
        (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        _wrapWithProviders(
          authProvider: authProvider,
          home: const LoginView(),
        ),
      );

      // Boş gönderimde hata mesajları görünür
      await tester.tap(find.text('Giriş Yap'));
      await tester.pump();

      expect(find.text('E-posta adresi gerekli.'), findsOneWidget);
      expect(find.text('Şifre gerekli.'), findsOneWidget);

      // Geçerli bilgilerle giriş yapar
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'ayse@ecotrack.org',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        '123456',
      );
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      expect(find.byType(MainShellView), findsOneWidget);
      expect(authProvider.hasActiveSession, isTrue);
      expect(authProvider.userModel?.email, 'ayse@ecotrack.org');
    });

    testWidgets('Şifremi Unuttum ekranı bağlantı gönderir ve onay kartı gösterir',
        (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        _wrapWithProviders(
          authProvider: authProvider,
          home: const LoginView(),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'zeynep@ecotrack.org',
      );
      await tester.tap(find.text('Şifremi Unuttum'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordView), findsOneWidget);
      expect(find.text('zeynep@ecotrack.org'), findsOneWidget);

      await tester.tap(find.text('Sıfırlama Bağlantısı Gönder'));
      await tester.pumpAndSettle();

      expect(find.text('Bağlantı Gönderildi'), findsOneWidget);
      expect(find.text('Giriş Ekranına Dön'), findsOneWidget);

      await tester.tap(find.text('Giriş Ekranına Dön'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets(
        'Yeni Kayıt ekranı şifre eşleşmesini kontrol eder, hesap oluşturur ve Profil çıkışıyla tekrar giriş yapılabilir',
        (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        _wrapWithProviders(
          authProvider: authProvider,
          home: const LoginView(),
        ),
      );

      await tester.ensureVisible(find.text('Kayıt Ol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kayıt Ol'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterView), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad Soyad'),
        'Zeynep Yılmaz',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'zeynep@ecotrack.org',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre Tekrar'),
        'farkli123',
      );

      await tester.ensureVisible(find.text('Kayıt Ol'));
      await tester.tap(find.text('Kayıt Ol'));
      await tester.pump();
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);

      // Doğru şifre tekrarı ile kayıt ol
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre Tekrar'),
        'secret123',
      );
      await tester.ensureVisible(find.text('Kayıt Ol'));
      await tester.tap(find.text('Kayıt Ol'));
      await tester.pumpAndSettle();

      expect(find.byType(MainShellView), findsOneWidget);
      expect(find.text('Hoş Geldin, Zeynep Yılmaz'), findsOneWidget);
      expect(authProvider.userModel?.ecoPoints, 0);
      expect(
        find.text('Hesabınız oluşturuldu! EcoTrack dünyasına hoş geldiniz.'),
        findsOneWidget,
      );

      // Yüzen SnackBar alt menüyü kapatmasın diye otomatik kapanmasını bekle
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Profil sekmesinden çıkış yap
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      final signOutBtn = find.byTooltip('Çıkış Yap');
      await tester.ensureVisible(signOutBtn);
      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Çıkış Yap').last);
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(authProvider.hasActiveSession, isFalse);

      // Yanlış şifre hatası
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'zeynep@ecotrack.org',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        'yanlis99',
      );
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginView), findsOneWidget);
      expect(find.text('Hatalı şifre. Lütfen tekrar deneyin.'), findsOneWidget);
    });
  });
}
