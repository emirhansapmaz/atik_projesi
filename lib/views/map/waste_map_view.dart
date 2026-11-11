import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/location_helper.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/waste_report_model.dart';
import '../../services/firestore_service.dart';
import '../report/create_report_view.dart';
import 'widgets/report_card_sheet.dart';

class WasteMapView extends StatefulWidget {
  final bool isActive;
  final bool hasFloatingNavBar;
  final WasteReportModel? focusedReport;
  final int focusRequestKey;
  final FirestoreService? firestoreService;
  final TileProvider? tileProvider;
  final Future<LocationResult> Function()? locationFetcher;

  const WasteMapView({
    super.key,
    this.isActive = true,
    this.hasFloatingNavBar = false,
    this.focusedReport,
    this.focusRequestKey = 0,
    this.firestoreService,
    this.tileProvider,
    this.locationFetcher,
  });

  @override
  State<WasteMapView> createState() => _WasteMapViewState();
}

class _WasteMapViewState extends State<WasteMapView>
    with TickerProviderStateMixin {
  static const LatLng _defaultIstanbulCenter = LatLng(
    LocationHelper.defaultLatitude,
    LocationHelper.defaultLongitude,
  );
  static const double _defaultZoom = 13.5;
  static const double _focusedZoom = 16.0;
  static const double _minZoom = 3.0;
  static const double _maxZoom = 19.0;
  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // OpenStreetMap karolarını mat antrasit karanlık temaya uyarlayan renk matrisi
  static const ColorFilter _darkOsmTileFilter = ColorFilter.matrix(<double>[
    0.309, -1.026, -0.103, 0, 224,
    -0.306, -0.411, -0.103, 0, 227,
    -0.306, -1.026, 0.512, 0, 233,
    0, 0, 0, 1, 0,
  ]);

  late final MapController _mapController;
  late final FirestoreService _firestoreService;
  late final Stream<List<WasteReportModel>> _reportsStream;

  TileProvider? _ownedTileProvider;
  AnimationController? _activeMoveController;
  Timer? _locateWatchdogTimer;
  bool _hasActivated = false;
  bool _isMapReady = false;
  bool _isLocating = false;
  bool _pendingMoveToUser = false;
  String _statusFilter = 'all'; // 'all' | 'pending' | 'resolved'
  LatLng _currentCenter = _defaultIstanbulCenter;
  LatLng? _userLocation;
  WasteReportModel? _activeFocusedReport;

  TileProvider _resolveTileProvider() {
    if (widget.tileProvider != null) {
      return widget.tileProvider!;
    }
    return _ownedTileProvider ??= NetworkTileProvider();
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _reportsStream = _firestoreService.getWasteReportsStream();
    _hasActivated = widget.isActive;
    if (widget.focusedReport != null) {
      _activeFocusedReport = widget.focusedReport;
      _currentCenter = LatLng(
        widget.focusedReport!.latitude,
        widget.focusedReport!.longitude,
      );
    }
    if (_hasActivated) {
      _resolveUserLocation(
        moveCameraOnSuccess: _activeFocusedReport == null,
        notifyLoadingStart: false,
      );
    }
  }

  @override
  void didUpdateWidget(covariant WasteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tileProvider != oldWidget.tileProvider &&
        widget.tileProvider != null) {
      _ownedTileProvider = null;
    }

    final hasNewFocusRequest = widget.focusedReport != null &&
        (widget.focusRequestKey != oldWidget.focusRequestKey ||
            widget.focusedReport?.id != oldWidget.focusedReport?.id);

    if (hasNewFocusRequest) {
      final report = widget.focusedReport!;
      final target = LatLng(report.latitude, report.longitude);
      _activeFocusedReport = report;
      _pendingMoveToUser = false;
      _statusFilter = 'all';
      _currentCenter = target;
    }

    if (widget.isActive && !_hasActivated) {
      _hasActivated = true;
      _resolveUserLocation(
        moveCameraOnSuccess: !hasNewFocusRequest && _activeFocusedReport == null,
        notifyLoadingStart: false,
      );
    } else if (hasNewFocusRequest && _isMapReady) {
      final target = LatLng(
        widget.focusedReport!.latitude,
        widget.focusedReport!.longitude,
      );
      _animatedMapMove(target, _focusedZoom);
    }
  }

  Future<void> _resolveUserLocation({
    bool moveCameraOnSuccess = false,
    bool showFeedbackOnFallback = false,
    bool notifyLoadingStart = true,
  }) async {
    if (_isLocating) return;
    if (notifyLoadingStart && mounted) {
      setState(() => _isLocating = true);
    } else {
      _isLocating = true;
    }

    _locateWatchdogTimer?.cancel();
    _locateWatchdogTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _isLocating) {
        setState(() => _isLocating = false);
      }
    });

    try {
      final fetcher = widget.locationFetcher ?? LocationHelper.getCurrentLocation;
      final loc = await fetcher();
      _locateWatchdogTimer?.cancel();
      if (!mounted) return;

      final resolvedLatLng = LatLng(loc.latitude, loc.longitude);
      final isFallback =
          (loc.latitude - LocationHelper.defaultLatitude).abs() < 0.0001 &&
          (loc.longitude - LocationHelper.defaultLongitude).abs() < 0.0001;

      setState(() {
        _userLocation = isFallback ? null : resolvedLatLng;
        if (_activeFocusedReport == null) {
          _currentCenter = resolvedLatLng;
        }
        _isLocating = false;
      });

      if (moveCameraOnSuccess && _activeFocusedReport == null) {
        if (_isMapReady) {
          _pendingMoveToUser = false;
          _animatedMapMove(
            resolvedLatLng,
            isFallback ? _defaultZoom : 15.0,
          );
        } else {
          _pendingMoveToUser = true;
        }
      }

      if (showFeedbackOnFallback && isFallback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Konum izni alınamadı, varsayılan İstanbul merkezi gösteriliyor.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _locateWatchdogTimer?.cancel();
      debugPrint('[WasteMapView] Konum alınırken hata: $e');
      if (!mounted) return;
      setState(() => _isLocating = false);
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _activeFocusedReport = null);
    if (_userLocation != null && _isMapReady) {
      _animatedMapMove(_userLocation!, 15.0);
    }
    await _resolveUserLocation(
      moveCameraOnSuccess: true,
      showFeedbackOnFallback: true,
    );
  }

  void _zoomBy(double delta) {
    if (!_isMapReady) return;
    final nextZoom = (_mapController.camera.zoom + delta).clamp(
      _minZoom,
      _maxZoom,
    );
    _animatedMapMove(_mapController.camera.center, nextZoom);
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!mounted || !_isMapReady) return;

    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    final latTween = Tween<double>(
      begin: startCenter.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: startCenter.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: startZoom,
      end: destZoom,
    );

    _activeMoveController?.dispose();
    final controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _activeMoveController = controller;

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );

    controller.addListener(() {
      if (!mounted || !_isMapReady) return;
      _mapController.move(
        LatLng(
          latTween.evaluate(animation),
          lngTween.evaluate(animation),
        ),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (_activeMoveController == controller) {
          _activeMoveController = null;
        }
        if (mounted) {
          controller.dispose();
        }
      }
    });

    controller.forward();
  }

  void _openReportSheet(WasteReportModel report) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportCardSheet(
        report: report,
        firestoreService: _firestoreService,
        onDeleted: () {
          if (_activeFocusedReport?.id == report.id && mounted) {
            setState(() => _activeFocusedReport = null);
          }
        },
      ),
    );
  }

  void _openCreateReport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateReportView(),
      ),
    );
  }

  List<WasteReportModel> _applyFilter(List<WasteReportModel> reports) {
    if (_statusFilter == 'pending') {
      return reports.where((r) => r.status == 'pending').toList();
    }
    if (_statusFilter == 'resolved') {
      return reports.where((r) => r.status == 'resolved').toList();
    }
    return reports;
  }

  @override
  void dispose() {
    _locateWatchdogTimer?.cancel();
    _locateWatchdogTimer = null;
    _activeMoveController?.dispose();
    _activeMoveController = null;
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasActivated) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Çevre Haritası')),
        body: const SizedBox.shrink(),
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final controlsBottom =
        widget.hasFloatingNavBar ? 110.0 + bottomInset : 20.0 + bottomInset;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor:
            AppColors.bgPrimaryOf(context).withValues(alpha: 0.78),
        title: const Text('Çevre Haritası'),
      ),
      body: StreamBuilder<List<WasteReportModel>>(
        stream: _reportsStream,
        builder: (context, snapshot) {
          final allReports = snapshot.data ?? const <WasteReportModel>[];
          final visibleReports =
              List<WasteReportModel>.from(_applyFilter(allReports));
          final focused = _activeFocusedReport;
          if (focused != null &&
              !visibleReports.any((r) => r.id == focused.id)) {
            visibleReports.insert(0, focused);
          }

          final pendingCount =
              allReports.where((r) => r.status == 'pending').length;
          final resolvedCount =
              allReports.where((r) => r.status == 'resolved').length;

          final markers = <Marker>[
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 34,
                height: 34,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryLight,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.my_location_rounded,
                      size: 16,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ),
            ...visibleReports.map((report) {
              final isPending = report.status == 'pending';
              final isFocused = focused?.id == report.id;
              final pinColor =
                  isPending ? AppColors.statusPending : AppColors.statusResolved;

              return Marker(
                key: ValueKey('marker_${report.id}'),
                point: LatLng(report.latitude, report.longitude),
                width: isFocused ? 42 : 36,
                height: isFocused ? 42 : 36,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => _openReportSheet(report),
                  child: Tooltip(
                    message:
                        '${report.wasteType} (${isPending ? "Bekliyor" : "Temizlendi"})',
                    child: _MinimalMapPin(
                      isPending: isPending,
                      isFocused: isFocused,
                      color: pinColor,
                    ),
                  ),
                ),
              );
            }),
          ];

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  backgroundColor: AppColors.bgPrimary,
                  initialCenter: focused != null
                      ? LatLng(focused.latitude, focused.longitude)
                      : _currentCenter,
                  initialZoom: focused != null ? _focusedZoom : _defaultZoom,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    if (!mounted) return;
                    _isMapReady = true;
                    if (_activeFocusedReport != null) {
                      _pendingMoveToUser = false;
                      _mapController.move(
                        LatLng(
                          _activeFocusedReport!.latitude,
                          _activeFocusedReport!.longitude,
                        ),
                        _focusedZoom,
                      );
                    } else if (_pendingMoveToUser) {
                      _pendingMoveToUser = false;
                      final target = _userLocation ?? _currentCenter;
                      final zoom =
                          _userLocation != null ? 15.0 : _defaultZoom;
                      _mapController.move(target, zoom);
                    }
                  },
                ),
                children: [
                  ColorFiltered(
                    colorFilter: Theme.of(context).brightness == Brightness.dark
                        ? _darkOsmTileFilter
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          ),
                    child: TileLayer(
                      urlTemplate: _osmTileUrl,
                      subdomains: const [],
                      retinaMode: false,
                      userAgentPackageName: 'com.ecotrack.app',
                      evictErrorTileStrategy:
                          EvictErrorTileStrategy.notVisibleRespectMargin,
                      tileProvider: _resolveTileProvider(),
                      errorTileCallback: (tile, error, stackTrace) {
                        debugPrint(
                          '[WasteMapView] Karo yüklenemedi (${tile.coordinates}): $error',
                        );
                      },
                    ),
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // Üst Durum / Filtre Çubuğu
              Positioned(
                top: kToolbarHeight + MediaQuery.paddingOf(context).top + 8,
                left: 14,
                right: 14,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'Tümü (${allReports.length})',
                        isSelected: _statusFilter == 'all',
                        color: AppColors.primaryLight,
                        onTap: () => setState(() => _statusFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Bekliyor ($pendingCount)',
                        icon: Icons.warning_amber_rounded,
                        isSelected: _statusFilter == 'pending',
                        color: AppColors.statusPending,
                        onTap: () => setState(() => _statusFilter = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Temizlendi ($resolvedCount)',
                        icon: Icons.check_circle_outline,
                        isSelected: _statusFilter == 'resolved',
                        color: AppColors.primaryLight,
                        onTap: () => setState(() => _statusFilter = 'resolved'),
                      ),
                    ],
                  ),
                ),
              ),

              // Odaklanılan İhbar Bilgi Kartı
              if (focused != null)
                Positioned(
                  top: kToolbarHeight + MediaQuery.paddingOf(context).top + 56,
                  left: 14,
                  right: 14,
                  child: SurfaceCard(
                    padding: EdgeInsets.zero,
                    color: AppColors.surfaceOf(context),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        onTap: () => _openReportSheet(focused),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtleOf(context),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surfaceBorderOf(context)),
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: focused.status == 'pending'
                                ? AppColors.statusPending
                                : AppColors.primaryLight,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          '${focused.wasteType} İhbarı',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        subtitle: Text(
                          focused.addressText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Odağı Kapat',
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.textSecondaryOf(context),
                          ),
                          onPressed: () {
                            setState(() => _activeFocusedReport = null);
                          },
                        ),
                      ),
                    ),
                  ),
                ),

              // Yükleniyor göstergesi
              if (snapshot.connectionState == ConnectionState.waiting &&
                  allReports.isEmpty)
                Positioned(
                  top: kToolbarHeight + MediaQuery.paddingOf(context).top + 60,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: SurfaceCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'İhbarlar yükleniyor...',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Harita Atıf Rozeti
              Positioned(
                left: 14,
                bottom: controlsBottom + 6,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.surfaceBorderOf(context)),
                    ),
                    child: Text(
                      '© OpenStreetMap katkıda bulunanlar',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Sade Mat Kontroller (Yakınlaştır/Uzaklaştır, "Konumuma Git" ve "İhbar Ekle")
              Positioned(
                right: 16,
                bottom: controlsBottom,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SurfaceCard(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.surfaceOf(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 46,
                            height: 42,
                            child: IconButton(
                              tooltip: 'Yakınlaştır',
                              onPressed: () => _zoomBy(1.0),
                              icon: Icon(
                                Icons.add,
                                color: AppColors.textPrimaryOf(context),
                                size: 20,
                              ),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 1,
                            color: AppColors.surfaceBorderOf(context),
                          ),
                          SizedBox(
                            width: 46,
                            height: 42,
                            child: IconButton(
                              tooltip: 'Uzaklaştır',
                              onPressed: () => _zoomBy(-1.0),
                              icon: Icon(
                                Icons.remove,
                                color: AppColors.textPrimaryOf(context),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SurfaceCard(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.surfaceOf(context),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: IconButton(
                          tooltip: 'Konumuma Git',
                          onPressed: _isLocating ? null : _goToCurrentLocation,
                          icon: _isLocating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryLight,
                                  ),
                                )
                              : Icon(
                                  Icons.my_location,
                                  color: AppColors.textPrimaryOf(context),
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SurfaceCard(
                      onTap: _openCreateReport,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.primarySage,
                      borderColor:
                          AppColors.primaryLight.withValues(alpha: 0.35),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_location_alt_outlined,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'İhbar Ekle',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MinimalMapPin extends StatelessWidget {
  final bool isPending;
  final bool isFocused;
  final Color color;

  const _MinimalMapPin({
    required this.isPending,
    required this.isFocused,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = isFocused ? 38.0 : 32.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: isFocused ? AppColors.textPrimary : color,
          width: isFocused ? 2.0 : 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          isPending ? Icons.location_on_rounded : Icons.check_rounded,
          color: color,
          size: isFocused ? 20 : 17,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.surfaceSubtleOf(context) : AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : AppColors.surfaceBorderOf(context),
          width: isSelected ? 1.2 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
              ] else ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.textPrimaryOf(context)
                      : AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
