import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../models/waste_report_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/map_provider.dart';
import '../../../services/firestore_service.dart';

/// Kullanıcı onayı ile atık ihbarını silen ortak yardımcı
Future<bool> confirmAndDeleteWasteReport(
  BuildContext context, {
  required WasteReportModel report,
  FirestoreService? firestoreService,
  VoidCallback? onConfirmed,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  AuthProvider? authProvider;
  MapProvider? mapProvider;
  try {
    authProvider = context.read<AuthProvider>();
  } catch (_) {}
  try {
    mapProvider = context.read<MapProvider>();
  } catch (_) {}

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('İhbarı Sil'),
      content: const Text(
        'Bu atık ihbarını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.statusError,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(0, 40),
          ),
          child: const Text('Sil'),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;
  onConfirmed?.call();

  try {
    if (firestoreService == null && mapProvider != null) {
      final ok = await mapProvider.deleteReport(
        report.id,
        userId: report.userId,
      );
      if (!ok) {
        throw Exception(mapProvider.errorMessage ?? 'İhbar silinemedi.');
      }
    } else {
      final service = firestoreService ?? FirestoreService();
      await service.deleteReport(report.id, userId: report.userId);
    }

    if (authProvider?.userModel?.uid == report.userId) {
      authProvider?.decrementReportCount();
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('İhbarınız silindi.'),
        backgroundColor: AppColors.surface,
      ),
    );
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('İhbar silinemedi: $e'),
        backgroundColor: AppColors.statusError,
      ),
    );
    return false;
  }
}

class ReportCardSheet extends StatefulWidget {
  final WasteReportModel report;
  final FirestoreService? firestoreService;
  final VoidCallback? onShowOnMap;
  final VoidCallback? onDeleted;

  const ReportCardSheet({
    super.key,
    required this.report,
    this.firestoreService,
    this.onShowOnMap,
    this.onDeleted,
  });

  @override
  State<ReportCardSheet> createState() => _ReportCardSheetState();
}

class _ReportCardSheetState extends State<ReportCardSheet> {
  bool _isResolving = false;
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    if (_isResolving || _isDeleting) return;
    final navigator = Navigator.of(context);

    final deleted = await confirmAndDeleteWasteReport(
      context,
      report: widget.report,
      firestoreService: widget.firestoreService,
      onConfirmed: () {
        if (mounted) setState(() => _isDeleting = true);
      },
    );

    if (!mounted) return;
    if (deleted) {
      widget.onDeleted?.call();
      navigator.pop(true);
    } else if (_isDeleting) {
      setState(() => _isDeleting = false);
    }
  }

  Future<void> _handleResolve() async {
    if (_isResolving) return;

    setState(() => _isResolving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      AuthProvider? authProvider;
      try {
        authProvider = context.read<AuthProvider>();
      } catch (_) {}

      final solverUid = authProvider?.userModel?.uid ?? 'demo_user_1';
      final service = widget.firestoreService ?? FirestoreService();

      await service.resolveReport(widget.report.id, solverUid);
      await service.addEcoPoints(solverUid, 15);
      authProvider?.applyPointsUpdate(15);

      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'İhbar temizlendi olarak işaretlendi! +15 Eco-Puan kazandınız.',
          ),
          backgroundColor: AppColors.surface,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('İşlem sırasında hata oluştu: $e'),
          backgroundColor: AppColors.statusError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final isPending = report.status == 'pending';
    final statusColor =
        isPending ? AppColors.statusPending : AppColors.statusResolved;
    final statusDisplayColor =
        isPending ? AppColors.statusPending : AppColors.primaryLight;
    final formattedDate =
        DateFormat('dd.MM.yyyy HH:mm').format(report.createdAt);

    AuthProvider? authProvider;
    try {
      authProvider = context.watch<AuthProvider>();
    } catch (_) {}
    final currentUid = authProvider?.userModel?.uid ?? 'demo_user_1';
    final canDelete = report.userId.isNotEmpty && report.userId == currentUid;
    final isBusy = _isResolving || _isDeleting;

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
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tutamaç çubuğu
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorderOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Atık Fotoğrafı
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorderOf(context)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    height: 184,
                    width: double.infinity,
                    child: _buildReportImage(report.imageUrl),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Atık Türü Başlığı ve Sade Durum Rozeti
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      report.wasteType,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  StatusPill(
                    label: isPending ? 'Bekliyor' : 'Temizlendi',
                    icon: isPending
                        ? Icons.pending_actions_outlined
                        : Icons.check_circle_outline,
                    color: statusDisplayColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    fontSize: 12,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Kullanıcı & Tarih Bilgisi
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaChip(
                    icon: Icons.person_outline,
                    label:
                        report.userName.isNotEmpty ? report.userName : 'Doğa Dostu',
                    color: AppColors.textSecondaryOf(context),
                  ),
                  _buildMetaChip(
                    icon: Icons.schedule,
                    label: formattedDate,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Konum Adres Metni
              SurfaceCard(
                color: AppColors.surfaceSubtleOf(context),
                borderColor: AppColors.surfaceBorderOf(context),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        report.addressText.isNotEmpty
                            ? report.addressText
                            : '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Kullanıcı Açıklaması (varsa)
              if (report.description.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                SurfaceCard(
                  color: AppColors.surfaceSubtleOf(context),
                  borderColor: AppColors.surfaceBorderOf(context),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Açıklama',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimaryOf(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              if (widget.onShowOnMap != null) ...[
                OutlinedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onShowOnMap!();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimaryOf(context),
                    side: BorderSide(color: AppColors.surfaceBorderOf(context)),
                  ),
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text('Haritada Göster'),
                ),
                const SizedBox(height: 10),
              ],

              if (isPending)
                ElevatedButton.icon(
                  onPressed: isBusy ? null : _handleResolve,
                  icon: _isResolving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: Text(
                    _isResolving
                        ? 'Güncelleniyor...'
                        : 'Temizlendi Olarak İşaretle (+15 Puan)',
                  ),
                )
              else
                SurfaceCard(
                  color: AppColors.surfaceSubtleOf(context),
                  borderColor: statusColor,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: AppColors.primaryLight,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Bu bölgedeki atık temizlenmiştir.',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Temizlenen ihbarlar 12 saat sonra otomatik kaldırılır.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),

              if (canDelete) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : _handleDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusError,
                    side: BorderSide(
                      color: AppColors.statusError.withValues(alpha: 0.45),
                    ),
                  ),
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.statusError,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(_isDeleting ? 'Siliniyor...' : 'İhbarı Sil'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtleOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportImage(String imageUrl) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty ||
        (!trimmed.startsWith('http://') && !trimmed.startsWith('https://'))) {
      return _buildFallbackPhoto();
    }

    return Image.network(
      trimmed,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: AppColors.surfaceSubtleOf(context),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryLight,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildFallbackPhoto(),
    );
  }

  Widget _buildFallbackPhoto() {
    return Container(
      color: AppColors.surfaceSubtleOf(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          Text(
            'Görsel yüklenemedi',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
