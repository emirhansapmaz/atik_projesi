import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/ecotrack_logo.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/waste_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../map/waste_map_view.dart';
import '../map/widgets/report_card_sheet.dart';
import '../report/create_report_view.dart';
import '../scan/scan_view.dart';

class HomeDashboardView extends StatefulWidget {
  final FirestoreService? firestoreService;
  final VoidCallback? onNavigateToScan;
  final VoidCallback? onNavigateToMap;
  final void Function(WasteReportModel report)? onShowReportOnMap;
  final bool hasFloatingNavBar;

  const HomeDashboardView({
    super.key,
    this.firestoreService,
    this.onNavigateToScan,
    this.onNavigateToMap,
    this.onShowReportOnMap,
    this.hasFloatingNavBar = false,
  });

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  static const double _co2PerRecycledItemKg = 0.12;

  static const List<String> _ecoTips = [
    '1 ton kağıdın geri dönüştürülmesiyle 17 ağaç kesilmekten kurtarılır!',
    'Cam ambalajlar kalitesini kaybetmeden sonsuz kez geri dönüştürülebilir.',
    '1 alüminyum kutuyu geri dönüştürmek, bir televizyonu 3 saat çalıştıracak kadar enerji tasarrufu sağlar.',
    'Plastik şişeleri kapağını çıkarıp ezerek sarı kutuya atmak toplama verimini artırır.',
  ];

  late final FirestoreService _firestoreService;
  late Stream<List<WasteReportModel>> _reportsStream;
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _reportsStream = _firestoreService.getWasteReportsStream();
  }

  Future<void> _handleRefresh() async {
    await _firestoreService.getWasteReports();
    if (!mounted) return;
    setState(() {
      _reportsStream = _firestoreService.getWasteReportsStream();
      _tipIndex = (_tipIndex + 1) % _ecoTips.length;
    });
  }

  void _openScan() {
    if (widget.onNavigateToScan != null) {
      widget.onNavigateToScan!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ScanView(isActive: true)),
    );
  }

  void _openCreateReport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateReportView()),
    );
  }

  void _openMap() {
    if (widget.onNavigateToMap != null) {
      widget.onNavigateToMap!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WasteMapView()),
    );
  }

  void _showReportOnMap(WasteReportModel report) {
    if (widget.onShowReportOnMap != null) {
      widget.onShowReportOnMap!(report);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WasteMapView(focusedReport: report),
      ),
    );
  }

  void _openActivityDetail(WasteReportModel report) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      builder: (_) => ReportCardSheet(
        report: report,
        firestoreService: _firestoreService,
        onShowOnMap: () => _showReportOnMap(report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AuthProvider? authProvider;
    try {
      authProvider = context.watch<AuthProvider>();
    } catch (_) {}

    final user = authProvider?.userModel;
    final rawName = user?.fullName.trim() ?? '';
    final displayName = rawName.isNotEmpty ? rawName : 'Çevre Gönüllüsü';
    final level = (user?.level.trim().isNotEmpty ?? false)
        ? user!.level
        : 'Fidan';
    final ecoPoints = user?.ecoPoints ?? 0;
    final recycledCount = user?.recycledCount ?? 0;
    final userReportCount = user?.reportCount ?? 0;
    final savedCo2Kg = (recycledCount * _co2PerRecycledItemKg).toStringAsFixed(2);
    final bottomPadding = widget.hasFloatingNavBar
        ? 110.0 + MediaQuery.paddingOf(context).bottom
        : 24.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const EcoTrackLogo(
          size: 38,
          borderRadius: 10,
          showBorder: true,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<WasteReportModel>>(
          stream: _reportsStream,
          builder: (context, snapshot) {
            final reports = snapshot.data ?? const <WasteReportModel>[];
            final resolvedCount =
                reports.where((r) => r.status == 'resolved').length;
            final recentReports = reports.take(4).toList();

            return RefreshIndicator(
              color: AppColors.primaryLight,
              backgroundColor: AppColors.surfaceOf(context),
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Sade Karşılama Alanı
                    _buildHeaderCard(
                      displayName: displayName,
                      level: level,
                      ecoPoints: ecoPoints,
                    ),
                    const SizedBox(height: 20),

                    // 2. Etki & Sayaç Kartları
                    const _SectionTitle(title: 'Çevresel Etkin'),
                    const SizedBox(height: 12),
                    _buildImpactMetricsGrid(
                      recycledCount: recycledCount,
                      savedCo2Kg: savedCo2Kg,
                      openedReportCount: userReportCount,
                      resolvedReportCount: resolvedCount,
                    ),
                    const SizedBox(height: 22),

                    // 3. Hızlı Erişim Butonları
                    const _SectionTitle(title: 'Hızlı İşlemler'),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                    const SizedBox(height: 20),

                    // 4. Günün Çevre İpucu (Sol kenarda 2px sage yeşil çizgi)
                    _buildDailyTipCard(),
                    const SizedBox(height: 22),

                    // 5. Son Aktiviteler Listesi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionTitle(title: 'Son Aktiviteler'),
                        TextButton(
                          onPressed: _openMap,
                          child: const Text('Haritada Gör'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildRecentActivities(recentReports),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String displayName,
    required String level,
    required int ecoPoints,
  }) {
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş Geldin, $displayName',
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    StatusPill(
                      label: level,
                      icon: Icons.verified_outlined,
                      color: AppColors.primaryLight,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtleOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorderOf(context)),
                ),
                child: Text(
                  '⭐ $ecoPoints Puan',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Atıklarını ayrıştır, çevredeki sorunları bildir ve doğaya nefes ol.',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactMetricsGrid({
    required int recycledCount,
    required String savedCo2Kg,
    required int openedReportCount,
    required int resolvedReportCount,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ImpactMetricCard(
            title: 'Geri Dönüştürülen',
            value: '$recycledCount Adet',
            subtitle: 'Taranan atık',
            icon: Icons.recycling_rounded,
            iconColor: AppColors.primaryLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ImpactMetricCard(
            title: 'CO₂ Tasarrufu',
            value: '$savedCo2Kg kg CO₂',
            subtitle: 'Karbon kazancı',
            icon: Icons.cloud_done_outlined,
            iconColor: AppColors.primaryLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ImpactMetricCard(
            title: 'Çevre İhbarları',
            value: '${openedReportCount + resolvedReportCount}',
            subtitle: '$openedReportCount açılan • $resolvedReportCount çözülen',
            icon: Icons.campaign_outlined,
            iconColor: AppColors.statusPending,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            label: 'Atık Tara',
            icon: Icons.camera_alt_outlined,
            accentColor: AppColors.primaryLight,
            onTap: _openScan,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _QuickActionButton(
            label: 'İhbar Bildir',
            icon: Icons.add_location_alt_outlined,
            accentColor: AppColors.statusPending,
            onTap: _openCreateReport,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _QuickActionButton(
            label: 'Atık Haritası',
            icon: Icons.map_outlined,
            accentColor: AppColors.primaryLight,
            onTap: _openMap,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyTipCard() {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 2,
                color: AppColors.primarySage,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtleOf(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorderOf(context)),
                        ),
                        child: const Icon(
                          Icons.eco_outlined,
                          color: AppColors.primaryLight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Günün Çevre İpucu',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryOf(context),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _ecoTips[_tipIndex],
                              style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivities(List<WasteReportModel> recentReports) {
    if (recentReports.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(24),
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
                Icons.recycling_outlined,
                size: 30,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Henüz aktivite bulunmuyor, ilk atığını tara!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openScan,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Hemen Tara'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: recentReports.map((report) {
        final isPending = report.status == 'pending';
        final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(report.createdAt);
        final statusColor =
            isPending ? AppColors.statusPending : AppColors.statusResolved;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SurfaceCard(
            padding: const EdgeInsets.all(16),
            onTap: () => _openActivityDetail(report),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: _buildActivityThumbnail(
                        report.imageUrl,
                        statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              report.wasteType,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            label: isPending ? 'Bekliyor' : 'Temizlendi',
                            color: statusColor,
                            showDot: true,
                            fontSize: 11,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        report.addressText.isNotEmpty
                            ? report.addressText
                            : 'Konum belirtildi',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMutedOf(context),
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _showReportOnMap(report),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: AppColors.primaryLight,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Haritada Göster',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityThumbnail(String imageUrl, Color accentColor) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty ||
        (!trimmed.startsWith('http://') && !trimmed.startsWith('https://'))) {
      return _buildFallbackThumb(context, accentColor);
    }

    return Image.network(
      trimmed,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallbackThumb(context, accentColor),
    );
  }

  Widget _buildFallbackThumb(BuildContext context, Color accentColor) {
    return Container(
      color: AppColors.surfaceSubtleOf(context),
      child: Icon(
        Icons.recycling_outlined,
        color: accentColor,
        size: 24,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryOf(context),
        letterSpacing: -0.1,
      ),
    );
  }
}

class _ImpactMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _ImpactMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtleOf(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceBorderOf(context)),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryOf(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.textMutedOf(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: AppColors.surfaceSubtleOf(context),
      borderColor: AppColors.surfaceBorderOf(context),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceBorderOf(context)),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
