# AKILLI ATIK TESPİT VE TAKİP UYGULAMASI (ECOTRACK)
## Antigravity / Cursor Geliştirme ve Mimari Direktifi

Bu belge, Flutter ve Firebase altyapısı kullanılarak geliştirilecek atık tespit, geri dönüşüm rehberi ve topluluk odaklı atık ihbar takip mobil uygulaması için Antigravity AI asistanına rehberlik etmek üzere hazırlanmıştır.

---

## 1. Temel Hedef ve Kapsam Kısıtları

### Temel Hedef
Kullanıcıların kamera aracılığıyla atıkları tarayıp türünü (Plastik, Cam, Kağıt, Metal, Organik) tespit ettiği, hangi konteynere atılması gerektiğini öğrendiği; çevreye bırakılmış atıkları harita üzerinde GPS koordinatlarıyla ihbar edebildiği ve bu ihbarların çözülme durumunu takip ettiği bir mobil bitirme projesidir.

### ⛔ KESİNLİKLE YAPILMAYACAKLAR (Negatif Kısıtlar)
1. **Harici Backend Kurma:** Node.js, Python FastAPI, Go, Django vb. bağımsız backend servisleri yazılmayacaktır. Tüm veri akışı ve oturum yönetimi doğrudan Flutter içerisinden **Firebase SDK** ile yürütülecektir.
2. **Google Maps API Kullanma:** Kredi kartı ve API-Key zorunluluğundan kaçınmak için harita bileşeni olarak kesinlikle **`flutter_map` (OpenStreetMap)** kullanılacaktır.
3. **Ücretli Bulut AI API'leri:** Google Cloud Vision veya AWS Rekognition gibi harici/ücretli API'ler kullanılmayacaktır. Model çıkarımı cihaz içinde **`tflite_flutter`** ile yerel (offline) yapılacaktır.
4. **Monolitik / Spagetti Kod:** Tüm mantığın tek bir dosyaya yığılmasına izin verilmeyecektir. View, ViewModel/Provider, Service ve Model katmanları kesinlikle ayrı dosyalarda tutulacaktır.
5. **Yarım Kalmış / Sahte Akışlar:** Ekranlarda çalışmayan sahte butonlar veya tamamlanmamış akışlar bırakılmayacaktır. Hata durumlarında mutlaka kullanıcıya `SnackBar` ile bilgi verilecektir.

### ✅ KESİNLİKLE YAPILACAKLAR (Pozitif Kısıtlar)
1. **Durum Yönetimi (State Management):** Temiz, anlaşılır ve modüler bir mimari için **`Provider`** yapısı kullanılacaktır.
2. **Kuralcı Null Safety ve Hata Yakalama:** Dart'ın güncel null-safety kurallarına tam uyulacak; Firebase ve kamera operasyonlarında `try-catch` blokları eksiksiz kurulacaktır.
3. **Responsive ve Modern Arayüz:** Doğa/çevre temasına uygun olarak yeşil (`#2E7D32`), zümrüt ve toprak tonlarında modern Material 3 tasarımı uygulanacaktır.
4. **Model Fallback (Yedek) Desteği:** Eğer `assets/models/waste_model.tflite` dosyası henüz eklenmemişse uygulama çökmeyecek, geliştirici modunda simüle edilmiş mantıklı bir sonuç üretecektir.

---

## 2. Klasör ve Mimari Yapısı (Feature-First)

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart        # Renk paleti
│   │   └── app_constants.dart     # Sabit metinler, atık kategorileri
│   ├── theme/
│   │   └── app_theme.dart         # Material 3 tema ayarları
│   └── utils/
│       └── location_helper.dart   # GPS ve koordinat izin kontrolleri
├── models/
│   ├── user_model.dart            # Kullanıcı puan ve profil modeli
│   └── waste_report_model.dart    # Atık ihbar ve tespit modeli
├── services/
│   ├── auth_service.dart          # Firebase Authentication
│   ├── firestore_service.dart     # Veritabanı okuma/yazma
│   ├── storage_service.dart       # Firebase Storage görsel yükleme
│   └── tflite_classifier.dart     # Cihaz içi atık sınıflandırma
├── providers/
│   ├── auth_provider.dart
│   ├── waste_provider.dart
│   └── map_provider.dart
├── views/
│   ├── auth/
│   │   ├── login_view.dart
│   │   └── register_view.dart
│   ├── home/
│   │   └── home_dashboard_view.dart
│   ├── scan/
│   │   ├── scan_view.dart
│   │   └── widgets/result_bottom_sheet.dart
│   ├── map/
│   │   ├── waste_map_view.dart
│   │   └── widgets/report_card_sheet.dart
│   ├── report/
│   │   └── create_report_view.dart
│   ├── profile/
│   │   └── profile_view.dart
│   └── navigation/
│       └── main_shell_view.dart   # Alt menü (BottomNavigationBar)
└── main.dart
```

---

## 3. Firestore Veritabanı Modelleri

### `users` Koleksiyonu
```json
{
  "uid": "USER_UID",
  "fullName": "Emirhan Sapmaz",
  "email": "user@example.com",
  "ecoPoints": 150,
  "level": "Doğa Dostu",
  "recycledCount": 15,
  "reportCount": 2,
  "createdAt": "Timestamp"
}
```

### `waste_reports` Koleksiyonu
```json
{
  "id": "REPORT_ID",
  "userId": "USER_UID",
  "userName": "Emirhan Sapmaz",
  "wasteType": "Plastik",
  "confidence": 0.93,
  "description": "Yol kenarında pet şişeler",
  "imageUrl": "https://firebasestorage.googleapis.com/...",
  "latitude": 41.0082,
  "longitude": 28.9784,
  "addressText": "Şişli, İstanbul",
  "status": "pending", // "pending" | "resolved"
  "resolvedBy": null,
  "createdAt": "Timestamp",
  "resolvedAt": null
}
```

---

## 4. Ekranlar ve Fonksiyonel Akışlar

1. **Giriş & Kayıt (`LoginView`, `RegisterView`):**
   - Firebase Auth ile e-posta/şifre doğrulaması.
   - Yeni kayıtta Firestore'da `users/{uid}` kaydı açılır (`ecoPoints: 0`).
2. **Ana Sayfa (`HomeDashboardView`):**
   - Toplam kazanılan Eco-Puan ve tahmini engellenen CO₂ miktarı sayacı.
   - Günlük çevre ipucu kartı.
   - Kullanıcının son yaptığı atık taramaları listesi.
3. **Atık Tarama (`ScanView`):**
   - Kamera vizörü veya galeriden resim seçme.
   - `TfliteClassifier` ile görsel sınıflandırma.
   - Sonuç Kartı (`ResultBottomSheet`): Atığın türü, hangi renk kutuya gideceği bilgisi ve iki aksiyon:
     - *"Geri Dönüştürdüm (+10 Puan)"* -> Kullanıcı puanını artırır.
     - *"Saha İhbarı Aç"* -> Resmi ve veriyi `CreateReportView` ekranına aktarır.
4. **Atık Haritası (`WasteMapView`):**
   - `flutter_map` ve OpenStreetMap ile harita çizimi.
   - Firestore'dan gelen anlık raporlar dinlenir:
     - Kırmızı Marker: Bekleyen (`pending`).
     - Yeşil Marker: Temizlenen (`resolved`).
   - Marker'a tıklandığında detay kartı açılır; *"Temizlendi"* butonu ile statü güncellenebilir.
5. **Yeni İhbar Formu (`CreateReportView`):**
   - Fotoğraf önizlemesi.
   - `geolocator` ile mevcut enlem/boylam ve `geocoding` ile adres tespiti.
   - Atık kategorisi seçimi ve açıklama girişi.
   - Firebase Storage'a yükleme ve Firestore'a kayıt.
6. **Profil & Sıralama (`ProfileView`):**
   - Kullanıcı puanı, seviye rozeti (Fidan, Doğa Dostu, Çevre Kahramanı).
   - En yüksek puana sahip ilk 10 kullanıcının listelendiği mini liderlik tablosu.

---

## 5. Antigravity İçin Geliştirme Adımları

1. **Aşama:** `pubspec.yaml` paketlerini kur ve `assets/` klasör yolunu aç.
2. **Aşama:** `core/constants` ve `models` katmanını oluştur.
3. **Aşama:** `AuthService`, `FirestoreService` ve `TfliteClassifier` sınıflarını implement et.
4. **Aşama:** `MainShellView` ile `BottomNavigationBar` iskeletini oluştur.
5. **Aşama:** Sırasıyla Dashboard, Scan, Map ve Profile ekranlarını bağla.