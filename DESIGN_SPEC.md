# ECOTRACK — MİNİMALİST & RAFİNE TASARIM SİSTEMİ (DESIGN SPEC)

Bu belge uygulamanın tüm görsel dilini sade, olgun ve modern bir çizgiye çekmek için hazırlanmıştır. Parlak neon renkler, sci-fi parlamalar (glow), lazer animasyonları ve karmaşık cam efektleri KESİNLİKLE KULLANILMAYACAKTIR.

---

## 1. Renk Paleti ve Tasarım Mantığı (lib/core/constants/app_colors.dart)

Tasarım; derin mat antrasit zemin, doğal çam/adaçayı yeşili (sage/pine) ve sakin gri tonları üzerine kuruludur.

- Zemin ve Yüzeyler:
  * bgPrimary: Color(0xFF0F1115) (Mat, doymamış koyu antrasit)
  * surface: Color(0xFF16191F) (Kart ve panel arka planı)
  * surfaceBorder: Color(0xFF242A35) (1px ince, zarif kenarlık)
  * surfaceSubtle: Color(0xFF1E232B) (Tıklanabilir buton ve çip dolguları)

- Vurgu ve Durum Renkleri (Mat ve Doğal):
  * primarySage: Color(0xFF2D6A4F) (Doğal orman/adaçayı yeşili — asla neon değil)
  * primaryLight: Color(0xFF52B788) (İkonlar ve aktif sekme vurgusu için mat açık yeşil)
  * textPrimary: Color(0xFFF1F3F5) (Yüksek kontrastlı kırık beyaz)
  * textSecondary: Color(0xFF8A94A6) (Açıklama ve alt metinler için yumuşak gri)
  * textMuted: Color(0xFF5A6272)
  * statusPending: Color(0xFFD97706) (Mat sıcak kehribar / beklemede)
  * statusResolved: Color(0xFF2D6A4F) (Mat zeytin/orman yeşili / çözüldü)

---

## 2. Temel Arayüz Kuralları

1. Parlama (Glow) ve Işık Efektleri Yasaktır:
   - Hiçbir BoxShadow içinde yayılma (spreadRadius) veya yüksek opaklıklı parlama kullanılmayacaktır. Kartlar düz mat renk (`surface`) ve 1px kılcal kenarlık (`surfaceBorder`) ile ayrışacaktır.
2. Tipografi Odaklı Hiyerarşi:
   - Başlıklar net, kalın ve okunabilir; gövde metinleri ferah satır aralıklı olmalıdır. Vurgu renklerle değil, font ağırlığı (FontWeight.w600 vs w400) ve boyutuyla yapılır.
3. Radikal Boşluk (Whitespace):
   - Elemanları birbirine sıkıştırma. Kart içi padding en az 16px, kartlar arası mesafe 14-18px olmalıdır.

---

## 3. Ekran Detayları

### A. MainShellView (Alt Navigasyon Barı):
- Ekranın altından 16px yukarıda duran, köşeleri hafif yuvarlatılmış (16px kavis) mat antrasit bir kapsayıcı (`surface`).
- Üzerinde sadece 1px `surfaceBorder` çizgisi bulunur.
- Aktif sekme: Basit bir mat yeşil (`primaryLight`) ikon ve altına 4px minik sade bir nokta. Asla neon ışık halkası olmamalıdır.

### B. HomeDashboardView (Ana Sayfa):
- Üst Karşılama: Sade tipografi ("Merhaba, Emirhan"), altında mat gri unvan.
- Sayaç Kartları: 3 ana metrik (Geri Dönüştürülen, CO₂, İhbarlar) yan yana minimal kartlar halinde dizilir. Sayı büyük ve net (24px, beyaz), etiket altında küçük mat gri (12px).
- Günün Çevre İpucu: Solunda sade 2px `primarySage` çizgisi olan minimal koyu kart.

### C. ScanView (Kamera & AI Tespiti):
- Lazer çizgileri, hareketli animasyonlar ve neon HUD grafikleri tamamen kaldırılacak.
- Vizör: Ekranın ortasında sadece köşeleri 1.5px inceliğinde beyaz çizgilerle belirlenmiş sade bir dikdörtgen çerçeve.
- Alt Bölüm: Mat daire deklanşör butonu ve sade galeri ikonu.
- Sonuç Kartı (BottomSheet): Mat antrasit yüzey, sade bir küçük fotoğraf önizlemesi, atık türü başlığı ve iki sade buton (Biri mat koyu yeşil dolgulu, diğeri sade gri outline).

### D. WasteMapView (Harita):
- Harita Katmanı: Koyu ama göz yormayan sakin karo sunucusu (CartoDB Dark Matter).
- Marker'lar: Dışa doğru dalgalanan radar efektleri kaldırılacak. Sade, minimal pin ikonu:
  * Bekleyen: Sade turuncu/kehribar pin (`statusPending`).
  * Çözülen: Sade orman yeşili pin (`statusResolved`).

### E. ProfileView & LeaderboardView:
- Şatafatlı altın/bronz neon podyumlar yerine; Linear / Notion benzeri minimal liste sıralaması (1, 2, 3 için küçük sade numara rozeti).
- Rozetler: Minimal gri arka planlı, açık olanlar sade zeytin/çam yeşili ikonlu düz kartlar.