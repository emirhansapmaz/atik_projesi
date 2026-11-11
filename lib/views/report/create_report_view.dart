import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/location_helper.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/waste_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/map_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class CreateReportView extends StatefulWidget {
  final File? initialImage;
  final Uint8List? initialImageBytes;
  final String? initialWasteType;
  final double confidence;
  final StorageService? storageService;
  final FirestoreService? firestoreService;
  final Future<LocationResult> Function()? locationFetcher;
  final Future<({double latitude, double longitude})?> Function(String address)?
      addressGeocoder;

  const CreateReportView({
    super.key,
    this.initialImage,
    this.initialImageBytes,
    this.initialWasteType,
    this.confidence = 0.90,
    this.storageService,
    this.firestoreService,
    this.locationFetcher,
    this.addressGeocoder,
  });

  @override
  State<CreateReportView> createState() => _CreateReportViewState();
}

class _CreateReportViewState extends State<CreateReportView> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  static const List<String> _wasteTypes = [
    'Plastik',
    'Cam',
    'Kağıt',
    'Metal',
    'Organik',
    'Elektronik',
    'Diğer',
  ];

  late String _selectedWasteType;
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  double? _latitude;
  double? _longitude;
  String? _lastAutoResolvedAddress;
  bool _isLoadingLocation = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedWasteType = _resolveInitialWasteType(widget.initialWasteType);
    _selectedImageFile = widget.initialImage;
    _selectedImageBytes = widget.initialImageBytes;
    _fetchLocation();
  }

  String _resolveInitialWasteType(String? incoming) {
    if (incoming == null || incoming.trim().isEmpty) {
      return _wasteTypes.first;
    }
    final normalized = incoming.trim().toLowerCase();
    for (final category in _wasteTypes) {
      if (category.toLowerCase() == normalized) {
        return category;
      }
    }
    return 'Diğer';
  }

  Future<void> _fetchLocation() async {
    if (mounted) {
      setState(() => _isLoadingLocation = true);
    }

    try {
      final fetcher = widget.locationFetcher ?? LocationHelper.getCurrentLocation;
      final loc = await fetcher();
      if (!mounted) return;
      setState(() {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        _lastAutoResolvedAddress = loc.address.trim();
        _addressController.text = loc.address;
        _isLoadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      _showSnackBar('Konum bilgisi alınamadı: $e', isError: true);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSubmitting) return;

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageFile = kIsWeb ? null : File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Fotoğraf seçilemedi: $e', isError: true);
    }
  }

  void _showImageSourceSelector() {
    if (_isSubmitting) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.surfaceBorderOf(context))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Fotoğraf Kaynağı Seç',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primaryLight,
                  ),
                  title: Text(
                    'Kameradan Çek',
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primaryLight,
                  ),
                  title: Text(
                    'Galeriden Seç',
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasSelectedImage =>
      _selectedImageBytes != null || (_selectedImageFile != null && !kIsWeb);

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    if (!_hasSelectedImage) {
      _showSnackBar('Lütfen atık fotoğrafı ekleyin.', isError: true);
      return;
    }

    final addressText = _addressController.text.trim();
    if (_latitude == null || _longitude == null || addressText.isEmpty) {
      _showSnackBar(
        'Konum veya adres bilgisi eksik. Lütfen konumu yenileyin.',
        isError: true,
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? true)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      AuthProvider? authProvider;
      MapProvider? mapProvider;
      try {
        authProvider = context.read<AuthProvider>();
      } catch (_) {}
      try {
        mapProvider = context.read<MapProvider>();
      } catch (_) {}

      final user = authProvider?.userModel;
      final userId = user?.uid ?? 'demo_user_1';
      final userName = user?.fullName ?? 'Doğa Dostu';

      // 1. StorageService ile fotoğrafı yükle ve downloadUrl al
      final storage = widget.storageService ?? StorageService();
      final String imageUrl;
      if (_selectedImageFile != null && !kIsWeb) {
        imageUrl = await storage.uploadReportImage(_selectedImageFile!);
      } else if (_selectedImageBytes != null) {
        imageUrl = await storage.uploadReportBytes(_selectedImageBytes!);
      } else {
        throw Exception('Yüklenecek geçerli bir görsel bulunamadı.');
      }

      // Kullanıcı adres metnini elle değiştirdiyse harita koordinatını da bu adrese eşitle
      var targetLat = _latitude!;
      var targetLng = _longitude!;
      if (addressText != _lastAutoResolvedAddress) {
        final geocoder =
            widget.addressGeocoder ?? LocationHelper.getCoordinatesFromAddress;
        final resolvedCoords = await geocoder(addressText);
        if (resolvedCoords != null) {
          targetLat = resolvedCoords.latitude;
          targetLng = resolvedCoords.longitude;
        }
      }

      // 2. WasteReportModel nesnesini oluştur
      final createdAt = Timestamp.now().toDate();
      final report = WasteReportModel(
        id: const Uuid().v4(),
        userId: userId,
        userName: userName,
        wasteType: _selectedWasteType,
        confidence: widget.confidence,
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        latitude: targetLat,
        longitude: targetLng,
        addressText: addressText,
        status: 'pending',
        createdAt: createdAt,
      );

      // 3. FirestoreService.createReport() ile 'waste_reports' koleksiyonuna ekle
      final firestore = widget.firestoreService ?? FirestoreService();
      try {
        if (widget.firestoreService == null && mapProvider != null) {
          final ok = await mapProvider.createReport(report);
          if (!ok) {
            debugPrint(
              '[CreateReportView] mapProvider createReport başarısız, doğrudan firestore deneniyor: ${mapProvider.errorMessage}',
            );
            await firestore.createReport(report);
          }
        } else {
          await firestore.createReport(report);
        }
      } catch (e) {
        debugPrint('[CreateReportView] createReport Firestore senkronizasyon uyarısı: $e');
      }

      // 4. Kullanıcıya +5 Çevre Puanı ekle
      try {
        await firestore.addEcoPoints(userId, 5);
      } catch (e) {
        debugPrint('[CreateReportView] addEcoPoints Firestore senkronizasyon uyarısı: $e');
      }
      authProvider?.applyPointsUpdate(5, isReport: true);

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      // 5. "İhbarınız İçin Teşekkürler!" Pop-up'ı göster
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => _ReportSuccessDialog(
          report: report,
          onClose: () {
            Navigator.of(dialogCtx).pop();
            Navigator.of(context).pop();
          },
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İhbar başarıyla gönderildi! +5 Çevre Puanı kazandınız.'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('İhbar gönderilemedi: $e', isError: true);
    } finally {
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.statusError : AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Saha İhbarı Oluştur'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isSubmitting,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Görsel Alanı
                      _buildImageSection(),
                      const SizedBox(height: 22),

                      // 2. Atık Türü Seçici
                      Text(
                        'Atık Kategorisi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _wasteTypes.map((type) {
                            final isSelected = type == _selectedWasteType;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(type),
                                selected: isSelected,
                                showCheckmark: false,
                                backgroundColor: AppColors.surfaceSubtleOf(context),
                                selectedColor: AppColors.primarySage,
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primaryLight
                                          .withValues(alpha: 0.45)
                                      : AppColors.surfaceBorderOf(context),
                                  width: 1.0,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimaryOf(context),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                onSelected: _isSubmitting
                                    ? null
                                    : (_) =>
                                        setState(() => _selectedWasteType = type),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 3. Konum & Adres Kartı
                      SurfaceCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.primaryLight,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Konum & Adres',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: AppColors.textPrimaryOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed:
                                      (_isLoadingLocation || _isSubmitting)
                                          ? null
                                          : _fetchLocation,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Konumu Yenile'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _addressController,
                              enabled: !_isSubmitting,
                              style: TextStyle(color: AppColors.textPrimaryOf(context)),
                              decoration: InputDecoration(
                                hintText: 'Konum alınıyor...',
                                prefixIcon: _isLoadingLocation
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primaryLight,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.place_outlined,
                                        color: AppColors.textSecondaryOf(context),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.gps_fixed_rounded,
                                  size: 13,
                                  color: (_latitude != null && _longitude != null)
                                      ? AppColors.primaryLight
                                      : AppColors.textMutedOf(context),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _latitude != null && _longitude != null
                                      ? 'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                                      : 'GPS koordinatı bekleniyor...',
                                  style: TextStyle(
                                    color: AppColors.textSecondaryOf(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. İsteğe Bağlı Açıklama Girişi
                      Text(
                        'Açıklama (İsteğe Bağlı)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_isSubmitting,
                        maxLines: 3,
                        style: TextStyle(color: AppColors.textPrimaryOf(context)),
                        decoration: const InputDecoration(
                          hintText: 'Örn: Kaldırım kenarında birikmiş şişeler',
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 5. 12 Saat Otomatik Kaldırma Bilgilendirmesi
                      SurfaceCard(
                        color: AppColors.surfaceSubtleOf(context),
                        borderColor: AppColors.surfaceBorderOf(context),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              size: 18,
                              color: AppColors.primaryLight,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Otomatik Kaldırma Bilgilendirmesi',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimaryOf(context),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Temizlendi olarak işaretlenen atık ihbarları 12 saat sonra otomatik olarak kaldırılır.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryOf(context),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 6. Gönder Butonu
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitReport,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('İhbarı Gönder (+5 Çevre Puanı)'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tam ekran yükleme katmanı (isSubmitting)
            if (_isSubmitting)
              Positioned.fill(
                child: Container(
                  color: AppColors.bgPrimary.withValues(alpha: 0.76),
                  child: const Center(
                    child: SurfaceCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primaryLight,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'İhbar gönderiliyor...',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    if (_hasSelectedImage) {
      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorderOf(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: 210,
                width: double.infinity,
                child: _selectedImageBytes != null
                    ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                    : Image.file(_selectedImageFile!, fit: BoxFit.cover),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _showImageSourceSelector,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceOf(context).withValues(alpha: 0.92),
                foregroundColor: AppColors.textPrimaryOf(context),
                side: BorderSide(color: AppColors.surfaceBorderOf(context)),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text(
                'Görseli Değiştir',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtleOf(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceBorderOf(context)),
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              size: 32,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Atık Fotoğrafı Yükle',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kamerayla çekin veya galeriden görsel seçin',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isSubmitting ? null : () => _pickImage(ImageSource.camera),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimaryOf(context),
                    side: BorderSide(color: AppColors.surfaceBorderOf(context)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isSubmitting ? null : () => _pickImage(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimaryOf(context),
                    side: BorderSide(color: AppColors.surfaceBorderOf(context)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportSuccessDialog extends StatelessWidget {
  final WasteReportModel report;
  final VoidCallback onClose;

  const _ReportSuccessDialog({
    required this.report,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.surfaceBorderOf(context)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.primaryLight,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'İhbarınız İçin Teşekkürler!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Çevre temizliğine ve geri dönüşüme verdiğiniz değerli katkı için teşekkür ederiz. İhbarınız sisteme başarıyla kaydedildi.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondaryOf(context),
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Özet Kartı
              SurfaceCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: AppColors.rankGold,
                          size: 18,
                        ),
                        Text(
                          '+5 Eco-Puan Kazandınız!',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: AppColors.surfaceBorderOf(context)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Atık Türü',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedOf(context),
                          ),
                        ),
                        Text(
                          report.wasteType,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Konum',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedOf(context),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            report.addressText,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtleOf(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 13,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Temizlenen ihbarlar 12 saat sonra otomatik kaldırılır.',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Tamam'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
