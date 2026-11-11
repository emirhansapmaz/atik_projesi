import 'package:ecotrack/main.dart';
import 'package:ecotrack/views/auth/login_view.dart';
import 'package:ecotrack/views/auth/splash_view.dart';
import 'package:ecotrack/views/navigation/main_shell_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EcoTrack app starts at Splash, transitions to Login and enters MainShell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EcoTrackApp());

    // Uygulama Splash ekranıyla başlar
    expect(find.byType(SplashView), findsOneWidget);
    expect(find.text('EcoTrack'), findsOneWidget);

    // Splash süresi dolduğunda Login ekranına yönlenir
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);

    // Demo girişi ile ana ekrana geçer
    await tester.tap(find.text('Demo Hesapla Devam Et'));
    await tester.pumpAndSettle();

    expect(find.byType(MainShellView), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Tara'), findsWidgets);
    expect(find.text('Harita'), findsWidgets);
    expect(find.text('Profil'), findsWidgets);
  });
}
