import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/waste_report_model.dart';
import '../home/home_dashboard_view.dart';
import '../map/waste_map_view.dart';
import '../profile/profile_view.dart';
import '../scan/scan_view.dart';

class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends State<MainShellView> {
  int _currentIndex = 0;
  WasteReportModel? _focusedMapReport;
  int _mapFocusNonce = 0;

  static const List<_NavTabItem> _tabs = [
    _NavTabItem(
      label: 'Ana Sayfa',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavTabItem(
      label: 'Tara',
      icon: Icons.qr_code_scanner_rounded,
      activeIcon: Icons.camera_alt_rounded,
    ),
    _NavTabItem(
      label: 'Harita',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
    ),
    _NavTabItem(
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              HomeDashboardView(
                hasFloatingNavBar: true,
                onNavigateToScan: () => setState(() => _currentIndex = 1),
                onNavigateToMap: () => setState(() => _currentIndex = 2),
                onShowReportOnMap: (report) {
                  setState(() {
                    _focusedMapReport = report;
                    _mapFocusNonce++;
                    _currentIndex = 2;
                  });
                },
              ),
              ScanView(
                isActive: _currentIndex == 1,
                hasFloatingNavBar: true,
              ),
              WasteMapView(
                isActive: _currentIndex == 2,
                hasFloatingNavBar: true,
                focusedReport: _focusedMapReport,
                focusRequestKey: _mapFocusNonce,
              ),
              const ProfileView(hasFloatingNavBar: true),
            ],
          ),

          // Sade mat alt navigasyon rıhtımı (dock)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + bottomInset,
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surfaceOf(context),
              borderColor: AppColors.surfaceBorderOf(context),
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final tab = _tabs[index];
                  final isSelected = _currentIndex == index;

                  return Expanded(
                    child: _MinimalDockButton(
                      item: tab,
                      isSelected: isSelected,
                      onTap: () => setState(() => _currentIndex = index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalDockButton extends StatelessWidget {
  final _NavTabItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _MinimalDockButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primarySage;
    final inactiveColor = AppColors.textSecondaryOf(context);
    final subtleBg = AppColors.surfaceSubtleOf(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: subtleBg,
        highlightColor: subtleBg,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? subtleBg : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 4,
                child: isSelected
                    ? Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
