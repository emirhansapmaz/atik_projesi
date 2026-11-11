import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/waste_provider.dart';
import '../../../services/tflite_classifier.dart';
import '../../report/create_report_view.dart';

class ResultBottomSheet extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final ClassificationResult result;

  const ResultBottomSheet({
    super.key,
    this.imageFile,
    this.imageBytes,
    required this.result,
  });

  @override
  State<ResultBottomSheet> createState() => _ResultBottomSheetState();
}

class _ResultBottomSheetState extends State<ResultBottomSheet> {
  bool _isSaving = false;

  String _toTurkishUpperCase(String text) {
    return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }

  _BinStyle _binStyleForWasteType(String wasteType) {
    switch (wasteType.toLowerCase()) {
      case 'plastik':
        return const _BinStyle(
          color: AppColors.plastic,
          icon: Icons.local_drink_outlined,
          title: 'Sarı Geri Dönüşüm Kutusu (Plastik)',
        );
      case 'kağıt':
      case 'kagit':
        return const _BinStyle(
          color: AppColors.paper,
          icon: Icons.article_outlined,
          title: 'Mavi Geri Dönüşüm Kutusu (Kağıt)',
        );
      case 'cam':
        return const _BinStyle(
          color: AppColors.glass,
          icon: Icons.wine_bar_outlined,
          title: 'Yeşil Cam Kumbarası (Cam)',
        );
      case 'metal':
        return const _BinStyle(
          color: AppColors.metal,
          icon: Icons.hardware_outlined,
          title: 'Gri Metal Kutusu (Metal)',
        );
      default:
        return const _BinStyle(
          color: AppColors.organic,
          icon: Icons.eco_outlined,
          title: 'Kahverengi Organik Kutusu',
        );
    }
  }

  Future<void> _handleRecycle() async {
    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final wasteProvider = context.read<WasteProvider>();
    final userId = authProvider.userModel?.uid ?? 'demo_user_1';

    final success = await wasteProvider.recordRecycle(userId);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      authProvider.applyPointsUpdate(10, isRecycle: true);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Harika! Geri dönüşüm için +10 Eco-Puan kazandınız.'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasteProvider.errorMessage ?? 'Puan eklenemedi.'),
          backgroundColor: AppColors.statusError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleReport() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => CreateReportView(
          initialImage: widget.imageFile,
          initialImageBytes: widget.imageBytes,
          initialWasteType: widget.result.wasteType,
          confidence: widget.result.confidence,
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (widget.imageBytes != null) {
      return Image.memory(
        widget.imageBytes!,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
      );
    }
    if (widget.imageFile != null && !kIsWeb) {
      return Image.file(
        widget.imageFile!,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: 72,
      height: 72,
      color: AppColors.surfaceSubtle,
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final binStyle = _binStyleForWasteType(result.wasteType);
    final normalizedConfidence = result.confidence.clamp(0.0, 1.0);
    final confidencePercent = (normalizedConfidence * 100).toStringAsFixed(1);
    final roundedPercent = (normalizedConfidence * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorderOf(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorderOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Thumbnail + Başlık + Doğruluk Göstergesi
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceBorderOf(context)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: _buildThumbnail(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: StatusPill(
                                label: '${result.wasteType} - %$confidencePercent',
                                color: AppColors.primaryLight,
                                showDot: true,
                              ),
                            ),
                            if (result.isMock) ...[
                              const SizedBox(width: 6),
                              const Tooltip(
                                message: 'Model dosyası yok, simüle edilmiş tahmin',
                                child: Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 16,
                                  color: AppColors.statusPending,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _toTurkishUpperCase(result.label),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: normalizedConfidence,
                          strokeWidth: 4,
                          backgroundColor: AppColors.surfaceSubtleOf(context),
                          color: AppColors.primaryLight,
                        ),
                        Center(
                          child: Text(
                            '%$roundedPercent',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Konteyner Bilgi Kutusu
              SurfaceCard(
                color: AppColors.surfaceSubtleOf(context),
                borderColor: AppColors.surfaceBorderOf(context),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: binStyle.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: binStyle.color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        binStyle.icon,
                        color: binStyle.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            binStyle.title,
                            style: TextStyle(
                              color: binStyle.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            result.disposalTip,
                            style: TextStyle(
                              fontSize: 13,
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

              // Aksiyon Butonları
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleRecycle,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.recycling_rounded, size: 18),
                label: Text(
                  _isSaving
                      ? 'Kaydediliyor...'
                      : 'Geri Dönüştürdüm (+10 Puan)',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _handleReport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimaryOf(context),
                  side: BorderSide(color: AppColors.surfaceBorderOf(context)),
                ),
                icon: const Icon(Icons.report_problem_outlined, size: 18),
                label: const Text('Sokağa Atılmış, İhbar Et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BinStyle {
  final Color color;
  final IconData icon;
  final String title;

  const _BinStyle({
    required this.color,
    required this.icon,
    required this.title,
  });
}
