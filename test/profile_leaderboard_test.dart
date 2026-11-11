import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ecotrack/models/user_model.dart';
import 'package:ecotrack/models/waste_report_model.dart';
import 'package:ecotrack/providers/auth_provider.dart';
import 'package:ecotrack/services/firestore_service.dart';
import 'package:ecotrack/views/leaderboard/leaderboard_view.dart';
import 'package:ecotrack/views/profile/profile_view.dart';

class _EmptyUserReportsFirestoreService extends FirestoreService {
  @override
  Stream<List<WasteReportModel>> getUserReportsStream(String userId) =>
      Stream<List<WasteReportModel>>.value(const <WasteReportModel>[]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FirestoreService.resetLocalDemoData();
  });

  group('FirestoreService Stage 6 Akış Testleri', () {
    test(
        'getLeaderboardStream kullanıcıları ecoPoints azalan sırada ve en fazla 20 kayıt döndürür',
        () async {
      final service = FirestoreService();

      final initialUsers = await service.getLeaderboardStream().first;
      expect(initialUsers.length, 6);
      expect(initialUsers.first.ecoPoints, 320);
      expect(initialUsers.last.ecoPoints, 40);

      for (var i = 0; i < initialUsers.length - 1; i++) {
        expect(
          initialUsers[i].ecoPoints,
          greaterThanOrEqualTo(initialUsers[i + 1].ecoPoints),
        );
      }

      // 20 limitini test etmek için ek kullanıcılar oluştur ve puan ekle
      final streamQueue = <List<UserModel>>[];
      final sub = service.getLeaderboardStream().listen(streamQueue.add);

      for (var i = 1; i <= 18; i++) {
        await service.createUserProfile(
          UserModel(
            uid: 'bulk_user_$i',
            fullName: 'Kullanıcı $i',
            email: 'user$i@ecotrack.org',
            ecoPoints: 20 + i * 10,
            level: 'Fidan',
            createdAt: DateTime(2026, 5, 1),
          ),
        );
      }
      await service.addEcoPoints('bulk_user_18', 300);
      await Future<void>.delayed(Duration.zero);

      final latest = streamQueue.last;
      expect(latest.length, 20);
      expect(latest.first.uid, 'bulk_user_18');
      expect(latest.first.ecoPoints, 500);
      for (var i = 0; i < latest.length - 1; i++) {
        expect(
          latest[i].ecoPoints,
          greaterThanOrEqualTo(latest[i + 1].ecoPoints),
        );
      }

      await sub.cancel();
    });

    test(
        'getUserReportsStream yalnızca ilgili kullanıcının ihbarlarını tarihe göre azalan getirir',
        () async {
      final service = FirestoreService();

      // Seeded veride user_1'e ait tek kayıt sample_1 (Sultanahmet) bulunur
      final user1Initial = await service.getUserReportsStream('user_1').first;
      expect(user1Initial.length, 1);
      expect(user1Initial.every((r) => r.userId == 'user_1'), isTrue);
      expect(
        user1Initial.any((r) => r.addressText.contains('Sultanahmet')),
        isTrue,
      );
      expect(
        user1Initial.any((r) => r.addressText.contains('Karaköy')),
        isFalse,
      );

      final events = <List<WasteReportModel>>[];
      final sub = service.getUserReportsStream('demo_user_1').listen(events.add);
      await Future<void>.delayed(Duration.zero);
      expect(events.first, isEmpty);

      final now = DateTime.now();
      await service.createReport(
        WasteReportModel(
          id: 'rep_demo_older',
          userId: 'demo_user_1',
          userName: 'Emirhan Sapmaz',
          wasteType: 'Plastik',
          confidence: 0.91,
          description: 'Eski tarihli test ihbarı',
          imageUrl: '',
          latitude: 41.03,
          longitude: 28.99,
          addressText: 'Taksim, İstanbul',
          status: 'pending',
          createdAt: now,
        ),
      );
      await service.createReport(
        WasteReportModel(
          id: 'rep_demo_newest',
          userId: 'demo_user_1',
          userName: 'Emirhan Sapmaz',
          wasteType: 'Cam',
          confidence: 0.96,
          description: 'Park girişinde cam şişeler',
          imageUrl: '',
          latitude: 41.045,
          longitude: 29.005,
          addressText: 'Beşiktaş, İstanbul',
          status: 'pending',
          createdAt: now.add(const Duration(minutes: 5)),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final latest = events.last;
      expect(latest.length, 2);
      expect(latest.first.id, 'rep_demo_newest');
      expect(latest.last.id, 'rep_demo_older');
      expect(latest.every((r) => r.userId == 'demo_user_1'), isTrue);

      final unknownUserReports =
          await service.getUserReportsStream('non_existent_user').first;
      expect(unknownUserReports, isEmpty);

      await sub.cancel();
    });
  });

  group('LeaderboardView Widget Testleri', () {
    testWidgets(
        'İlk 3 podyumda, 4+ sırada ListView.builder içinde gösterilir ve ilk 3 dışındaki kullanıcı için Sizin Sıranız sabitlenir',
        (WidgetTester tester) async {
      final authProvider = AuthProvider(); // demo_user_1 -> 150 Puan (4. sıra)

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: LeaderboardView(
              firestoreService: FirestoreService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Podyum değerleri
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
      expect(find.text('320 Puan'), findsOneWidget);
      expect(find.text('245 Puan'), findsOneWidget);
      expect(find.text('195 Puan'), findsOneWidget);

      // 4. sıradan itibaren ListView.builder
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('4.'), findsOneWidget);

      // Alt sabitlenmiş "Sizin Sıranız" kartı
      expect(find.text('Sizin Sıranız'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('150 Puan'), findsAtLeastNWidgets(2));
    });

    testWidgets(
        'Kullanıcı ilk 3 içine girdiğinde Sizin Sıranız sabit alt kartı gizlenir',
        (WidgetTester tester) async {
      final topUser = UserModel(
        uid: 'demo_user_1',
        fullName: 'Emirhan Sapmaz',
        email: 'emirhan@ecotrack.org',
        ecoPoints: 400,
        level: 'Çevre Kahramanı',
        recycledCount: 30,
        reportCount: 5,
        createdAt: DateTime(2026, 4, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LeaderboardView(
            firestoreService: FirestoreService(),
            currentUserOverride: topUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emirhan Sapmaz (Sen)'), findsOneWidget);
      expect(find.text('400 Puan'), findsOneWidget);
      expect(find.text('Sizin Sıranız'), findsNothing);
    });
  });

  group('ProfileView Widget Testleri', () {
    testWidgets(
        'Kullanıcı bilgileri, seviye ilerlemesi, rozetler, ad düzenleme ve Açtığım İhbarlar çalışır',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();
      final service = FirestoreService();
      await service.createReport(
        WasteReportModel(
          id: 'rep_demo_profile_1',
          userId: 'demo_user_1',
          userName: 'Emirhan Sapmaz',
          wasteType: 'Plastik',
          confidence: 0.94,
          description: 'Sahil kenarında pet şişeler',
          imageUrl: '',
          latitude: 40.991,
          longitude: 29.027,
          addressText: 'Kadıköy Sahil, İstanbul',
          status: 'pending',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: ProfileView(
              firestoreService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Profil bilgileri & istatistikler
      expect(find.text('Profil & Başarımlar'), findsOneWidget);
      expect(find.text('Emirhan Sapmaz'), findsOneWidget);
      expect(find.text('Doğa Dostu'), findsWidgets);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Rozetler (150 puan, 15 geri dönüşüm, 2 ihbar -> 4/5 açık)
      expect(find.text('Kazanılan Rozetler (4/5)'), findsOneWidget);
      expect(find.text('İlk Adım'), findsOneWidget);
      expect(find.text('Çevre Gözcüsü'), findsOneWidget);
      expect(find.text('Geri Dönüşüm Ustası'), findsOneWidget);
      expect(find.text('Çevre Kahramanı'), findsOneWidget);

      // Açtığım İhbarlar yalnızca demo_user_1 kayıtlarını gösterir
      expect(find.text('Açtığım İhbarlar'), findsOneWidget);
      expect(find.textContaining('Kadıköy Sahil, İstanbul'), findsOneWidget);
      expect(find.textContaining('Sultanahmet Meydanı'), findsNothing);
      expect(find.textContaining('Karaköy Rıhtım'), findsNothing);

      // Ad düzenleme akışı
      await tester.tap(find.byTooltip('Adı Düzenle'));
      await tester.pumpAndSettle();

      expect(find.text('Profil Adını Düzenle'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Deniz Yılmaz');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(authProvider.userModel?.fullName, 'Deniz Yılmaz');
      expect(find.text('Deniz Yılmaz'), findsOneWidget);
      expect(find.text('Profil adınız güncellendi.'), findsOneWidget);

      // Liderlik tablosu navigasyonu
      final leaderboardBanner = find.text('Liderlik Tablosunu Gör');
      await tester.ensureVisible(leaderboardBanner);
      await tester.tap(leaderboardBanner);
      await tester.pumpAndSettle();

      expect(find.text('Liderlik Tablosu'), findsOneWidget);
      expect(find.text('Sizin Sıranız'), findsOneWidget);
    });

    testWidgets('Kullanıcının ihbarı yoksa temiz boş durum kartı gösterilir',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: ProfileView(
              firestoreService: _EmptyUserReportsFirestoreService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Henüz oluşturduğunuz bir ihbar bulunmuyor.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Kullanıcı Profildeki Açtığım İhbarlar listesinden kendi ihbarını silebilir',
        (WidgetTester tester) async {
      final service = FirestoreService();
      final authProvider = AuthProvider(firestoreService: service);
      await service.createReport(
        WasteReportModel(
          id: 'rep_profile_delete_1',
          userId: 'demo_user_1',
          userName: 'Emirhan Sapmaz',
          wasteType: 'Cam',
          confidence: 0.90,
          description: 'Silinecek profil ihbarı',
          imageUrl: '',
          latitude: 41.0422,
          longitude: 29.0067,
          addressText: 'Beşiktaş Çarşı, İstanbul',
          status: 'pending',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: ProfileView(
              firestoreService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Beşiktaş Çarşı, İstanbul'), findsOneWidget);

      final deleteButton = find.byTooltip('İhbarı Sil');
      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sil'));
      await tester.pumpAndSettle();

      expect(find.text('İhbarınız silindi.'), findsOneWidget);
      expect(find.textContaining('Beşiktaş Çarşı, İstanbul'), findsNothing);
      expect(
        find.text('Henüz oluşturduğunuz bir ihbar bulunmuyor.'),
        findsOneWidget,
      );
      expect(authProvider.userModel?.reportCount, 1);
    });

    testWidgets(
        'Profil düzenlemede ad, şehir, telefon, biyografi ve şifre değiştirilebilir',
        (WidgetTester tester) async {
      final service = FirestoreService();
      final authProvider = AuthProvider(firestoreService: service);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: ProfileView(
              firestoreService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Adı Düzenle'));
      await tester.pumpAndSettle();

      // Form alanları
      expect(find.text('Profil Adını Düzenle'), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);
      expect(find.text('Galeri'), findsOneWidget);
      expect(find.text('Şifre Değiştir (İsteğe Bağlı)'), findsOneWidget);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6)); // Ad, Şehir, Telefon, Bio, Yeni Şifre, Onay

      await tester.enterText(textFields.at(0), 'Ayşe Kaya');
      await tester.enterText(textFields.at(1), 'İzmir, Karşıyaka');
      await tester.enterText(textFields.at(2), '+90 532 999 8877');
      await tester.enterText(textFields.at(3), 'Sıfır atık yaşam tarzını benimsiyorum.');
      await tester.enterText(textFields.at(4), 'yeniSifre123');
      await tester.enterText(textFields.at(5), 'yeniSifre123');

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(authProvider.userModel?.fullName, 'Ayşe Kaya');
      expect(authProvider.userModel?.city, 'İzmir, Karşıyaka');
      expect(authProvider.userModel?.phoneNumber, '+90 532 999 8877');
      expect(authProvider.userModel?.bio,
          'Sıfır atık yaşam tarzını benimsiyorum.');

      // Profil kartında güncellenen bilgilerin görünümü
      expect(find.text('Ayşe Kaya'), findsOneWidget);
      expect(find.text('“Sıfır atık yaşam tarzını benimsiyorum.”'), findsOneWidget);
      expect(find.text('İzmir, Karşıyaka'), findsOneWidget);
      expect(find.text('+90 532 999 8877'), findsOneWidget);
    });
  });
}
