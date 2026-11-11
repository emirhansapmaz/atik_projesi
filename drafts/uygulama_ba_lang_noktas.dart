import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firestore_service.dart';
import 'services/tflite_classifier.dart';
import 'views/navigation/main_shell_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase projesi bağlandığında bu satır çalışır:
  // await Firebase.initializeApp();

  final classifier = TfliteClassifier();
  await classifier.init();

  runApp(const EcoTrackApp());
}

class EcoTrackApp extends StatelessWidget {
  const EcoTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoTrack - Atık Tespit ve Takip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Doğa Yeşili
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF388E3C),
        ),
      ),
      home: const MainShellView(),
    );
  }
}