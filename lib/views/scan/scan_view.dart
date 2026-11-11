import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/surface_card.dart';
import '../../providers/waste_provider.dart';
import 'widgets/result_bottom_sheet.dart';

class ScanView extends StatefulWidget {
  final bool isActive;
  final bool hasFloatingNavBar;

  const ScanView({
    super.key,
    this.isActive = true,
    this.hasFloatingNavBar = false,
  });

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> with WidgetsBindingObserver {
  CameraController? _cameraController;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isCameraInitialized = false;
  bool _isInitializingCamera = false;
  bool _isPermissionDenied = false;
  bool _isPermanentlyDenied = false;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _initCamera();
    }
  }

  @override
  void didUpdateWidget(covariant ScanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initCamera();
    } else if (!widget.isActive && oldWidget.isActive) {
      _disposeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (controller != null &&
          controller.value.isInitialized &&
          !_isInitializingCamera) {
        _disposeCamera();
      }
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      if (!_isCameraInitialized && !_isInitializingCamera) {
        _initCamera();
      }
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
        _isFlashOn = false;
      });
    }
    try {
      await controller?.dispose();
    } catch (e) {
      debugPrint('[ScanView] Kamera kapatma hatası: $e');
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializingCamera) return;
    _isInitializingCamera = true;

    try {
      if (!kIsWeb) {
        PermissionStatus status = await Permission.camera.status;
        if (status.isDenied) {
          status = await Permission.camera.request();
        }

        if (!mounted) return;

        if (status.isPermanentlyDenied) {
          setState(() {
            _isPermissionDenied = true;
            _isPermanentlyDenied = true;
            _isCameraInitialized = false;
            _cameraErrorMessage =
                'Kamera izni kalıcı olarak reddedildi. Aşağıdan galeriyi kullanabilir veya ayarlardan izin verebilirsiniz.';
          });
          return;
        }

        if (!status.isGranted) {
          setState(() {
            _isPermissionDenied = true;
            _isPermanentlyDenied = false;
            _isCameraInitialized = false;
            _cameraErrorMessage =
                'Canlı tarama için kamera izni gerekli. Dilerseniz galeriden fotoğraf seçebilirsiniz.';
          });
          return;
        }
      }

      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() {
          _isPermissionDenied = false;
          _isCameraInitialized = false;
          _cameraErrorMessage =
              'Cihazda kullanılabilir kamera bulunamadı. Galeriden fotoğraf seçebilirsiniz.';
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted || !widget.isActive) {
        await controller.dispose();
        return;
      }

      await _cameraController?.dispose();
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _isPermissionDenied = false;
        _isPermanentlyDenied = false;
        _cameraErrorMessage = null;
      });
    } catch (e) {
      debugPrint('[ScanView] Kamera başlatma hatası: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _cameraErrorMessage =
              'Kamera başlatılamadı. Galeriden fotoğraf seçerek atık analizi yapabilirsiniz.';
        });
      }
    } finally {
      _isInitializingCamera = false;
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      final nextFlash = !_isFlashOn;
      await controller.setFlashMode(nextFlash ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() => _isFlashOn = nextFlash);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Flaş bu cihazda değiştirilemedi.', isError: true);
      }
    }
  }

  Future<void> _captureAndClassify() async {
    final controller = _cameraController;
    if (_isProcessing) return;

    if (controller == null || !controller.value.isInitialized) {
      _showSnackBar(
        'Kamera hazır değil. Lütfen galeriden fotoğraf seçin.',
        isError: true,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile capturedFile = await controller.takePicture();
      if (_isFlashOn) {
        await controller.setFlashMode(FlashMode.off);
        if (mounted) setState(() => _isFlashOn = false);
      }
      await _processXFile(capturedFile);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackBar('Fotoğraf çekilemedi: $e', isError: true);
      }
    }
  }

  Future<void> _pickFromGalleryAndClassify() async {
    if (_isProcessing) return;

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) return;

      if (mounted) {
        setState(() => _isProcessing = true);
      }
      await _processXFile(picked);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackBar('Galeriden görsel seçilemedi: $e', isError: true);
      }
    }
  }

  Future<void> _processXFile(XFile xFile) async {
    final wasteProvider = context.read<WasteProvider>();
    final Uint8List bytes = await xFile.readAsBytes();
    final File? localFile = kIsWeb ? null : File(xFile.path);

    final result = await wasteProvider.analyzeBytes(bytes, file: localFile);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result == null) {
      _showSnackBar(
        wasteProvider.errorMessage ?? 'Atık sınıflandırılamadı.',
        isError: true,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResultBottomSheet(
        imageFile: localFile,
        imageBytes: bytes,
        result: result,
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Tam Ekran Kamera Vizörü veya Sade Yedek Görünüm
          _buildCameraPreviewOrFallback(),

          // 2. Üst Bar ve Flaş Kontrolü
          _buildTopBar(),

          // 3. 1.5px Sade İnce Odaklama Çerçevesi
          if (_isCameraInitialized) _buildBoundingFrame(),

          // 4. Alt Kontrol Çubuğu
          _buildBottomControls(),

          // 5. Çıkarım Süresince Sade Yüklenme Katmanı
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraPreviewOrFallback() {
    final controller = _cameraController;
    if (_isCameraInitialized &&
        controller != null &&
        controller.value.isInitialized) {
      final previewSize = controller.value.previewSize;
      final double previewWidth =
          kIsWeb ? (previewSize?.width ?? 1280) : (previewSize?.height ?? 720);
      final double previewHeight =
          kIsWeb ? (previewSize?.height ?? 720) : (previewSize?.width ?? 1280);

      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewWidth,
              height: previewHeight,
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sade 1.5px odaklama çerçevesi (kamera hazır değilken de sakin vizör yapısı)
          IgnorePointer(
            child: SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(
                painter: _MinimalFocusFramePainter(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SurfaceCard(
                padding: const EdgeInsets.all(20),
                borderRadius: BorderRadius.circular(48),
                color: AppColors.surface,
                child: Icon(
                  _isPermissionDenied
                      ? Icons.no_photography_outlined
                      : Icons.qr_code_scanner_rounded,
                  size: 40,
                  color: _isPermissionDenied
                      ? AppColors.statusPending
                      : AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _cameraErrorMessage ?? 'Vizör hazırlanıyor...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              if (_isPermissionDenied)
                ElevatedButton.icon(
                  onPressed: _isPermanentlyDenied ? openAppSettings : _initCamera,
                  icon: Icon(
                    _isPermanentlyDenied
                        ? Icons.settings_outlined
                        : Icons.refresh_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isPermanentlyDenied
                        ? 'Uygulama Ayarlarını Aç'
                        : 'Kamera İzni Ver',
                  ),
                )
              else if (_cameraErrorMessage != null)
                OutlinedButton.icon(
                  onPressed: _initCamera,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Kamerayı Tekrar Dene'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surface.withValues(alpha: 0.9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Atık Tara',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isCameraInitialized)
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surface.withValues(alpha: 0.9),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: _toggleFlash,
                      icon: Icon(
                        _isFlashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        size: 20,
                        color: _isFlashOn
                            ? AppColors.statusPending
                            : AppColors.textPrimary,
                      ),
                      tooltip: 'Flaş',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoundingFrame() {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: _MinimalFocusFramePainter(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface.withValues(alpha: 0.88),
              child: const Text(
                'Atığı çerçevenin içine hizalayın',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPad =
        widget.hasFloatingNavBar ? 112.0 + bottomInset : 28.0 + bottomInset;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad),
        color: AppColors.bgPrimary.withValues(alpha: 0.88),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Galeri Seçimi (Mat ikon buton)
            _MinimalControlButton(
              icon: Icons.photo_library_outlined,
              label: 'Galeri',
              onTap: _isProcessing ? null : _pickFromGalleryAndClassify,
            ),

            // Sade Mat Dairesel Deklanşör Butonu
            GestureDetector(
              onTap: (_isProcessing || !_isCameraInitialized)
                  ? null
                  : _captureAndClassify,
              child: Opacity(
                opacity: (_isCameraInitialized && !_isProcessing) ? 1.0 : 0.45,
                child: Container(
                  width: 74,
                  height: 74,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primarySage,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

            // İşlem / Model Durum Göstergesi
            SizedBox(
              width: 68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Center(
                      child: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryLight,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_outlined,
                              color: AppColors.primaryLight,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isProcessing ? 'Analiz...' : 'TFLite',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: AppColors.bgPrimary.withValues(alpha: 0.76),
      child: const Center(
        child: SurfaceCard(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryLight,
              ),
              SizedBox(height: 16),
              Text(
                'Atık analiz ediliyor...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Cihaz içi yapay zeka devrede',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MinimalControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Icon(icon, color: AppColors.textPrimary, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalFocusFramePainter extends CustomPainter {
  final Color color;

  const _MinimalFocusFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double corner = 24;
    final double w = size.width;
    final double h = size.height;

    final path = Path()
      // Sol üst
      ..moveTo(0, corner)
      ..lineTo(0, 0)
      ..lineTo(corner, 0)
      // Sağ üst
      ..moveTo(w - corner, 0)
      ..lineTo(w, 0)
      ..lineTo(w, corner)
      // Sağ alt
      ..moveTo(w, h - corner)
      ..lineTo(w, h)
      ..lineTo(w - corner, h)
      // Sol alt
      ..moveTo(corner, h)
      ..lineTo(0, h)
      ..lineTo(0, h - corner);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MinimalFocusFramePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
