import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ecotrack/core/constants/app_colors.dart';
import 'package:ecotrack/core/theme/app_theme.dart';
import 'package:ecotrack/core/widgets/surface_card.dart';
import 'package:ecotrack/providers/theme_provider.dart';

void main() {
  group('Aydınlık ve Karanlık Tema Testleri (ThemeMode)', () {
    test('ThemeProvider varsayılan olarak karanlık modda başlar ve toggleTheme ile geçiş yapar', () {
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDarkMode, isTrue);

      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDarkMode, isFalse);

      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDarkMode, isTrue);

      provider.setThemeMode(ThemeMode.light);
      expect(provider.isDarkMode, isFalse);
    });

    test('AppTheme.lightTheme aydınlık palet değerlerini doğru uygular', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, AppColors.bgPrimaryLight);
      expect(lightTheme.colorScheme.surface, AppColors.surfaceLight);
      expect(lightTheme.colorScheme.primary, AppColors.primarySage);
    });

    testWidgets('SurfaceCard aydınlık temada surfaceLight ve surfaceBorderLight renklerini kullanır', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            backgroundColor: AppColors.bgPrimaryLight,
            body: Center(
              child: SurfaceCard(
                child: Text('Aydınlık Kart'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Aydınlık Kart'), findsOneWidget);

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(SurfaceCard),
          matching: find.byType(Material),
        ),
      );

      expect(material.color, AppColors.surfaceLight);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.surfaceBorderLight);
    });

    testWidgets('Consumer<ThemeProvider> üzerinden dinamik tema değişimi çalışır', (tester) async {
      final provider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: provider,
          child: Consumer<ThemeProvider>(
            builder: (context, theme, _) {
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: theme.themeMode,
                home: Builder(
                  builder: (ctx) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    return Scaffold(
                      body: Text(isDark ? 'Tema: Koyu' : 'Tema: Açık'),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Tema: Koyu'), findsOneWidget);

      provider.toggleTheme();
      await tester.pumpAndSettle();

      expect(find.text('Tema: Açık'), findsOneWidget);
    });
  });
}
