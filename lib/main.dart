import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/map_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/waste_provider.dart';
import 'services/tflite_classifier.dart';
import 'views/auth/splash_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase başlatma (Varsayılan options desteğiyle)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[Firebase] Başarıyla başlatıldı.');
    }
  } catch (e) {
    debugPrint('[Firebase] Başlatma hatası yakalandı (güvenli fallback devrede): $e');
  }

  // Cihaz içi TFLite sınıflandırıcısını hazırla
  final classifier = TfliteClassifier();
  await classifier.init();

  runApp(EcoTrackApp(classifier: classifier));
}

class EcoTrackApp extends StatelessWidget {
  final TfliteClassifier? classifier;

  const EcoTrackApp({super.key, this.classifier});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WasteProvider(classifier: classifier)),
        ChangeNotifierProvider(create: (_) => MapProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: '${AppConstants.appName} - ${AppConstants.appTagline}',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashView(),
          );
        },
      ),
    );
  }
}
