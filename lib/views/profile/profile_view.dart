import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/user_model.dart';
import '../../models/waste_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../auth/login_view.dart';
import '../leaderboard/leaderboard_view.dart';
import '../map/waste_map_view.dart';
import '../map/widgets/report_card_sheet.dart';
import '../report/create_report_view.dart';

class ProfileView extends StatefulWidget {
  final FirestoreService? firestoreService;
  final bool hasFloatingNavBar;

  const ProfileView({
    super.key,
    this.firestoreService,
    this.hasFloatingNavBar = false,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final FirestoreService _firestoreService;
  String? _activeUserId;
  late Stream<List<WasteReportModel>> _userReportsStream;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _userReportsStream = _firestoreService.getUserReportsStream('demo_user_1');
    _activeUserId = 'demo_user_1';
  }

  void _syncReportsStream(String uid) {
    if (_activeUserId != uid) {
      _activeUserId = uid;
      _userReportsStream = _firestoreService.getUserReportsStream(uid);
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _showEditProfileDialog(
    AuthProvider? authProvider,
    UserModel currentUser,
  ) async {
    if (authProvider == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditProfileDialog(
        user: currentUser,
        authProvider: authProvider,
        storageService: StorageService(),
      ),
    );
  }

  void _openLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeaderboardView(firestoreService: _firestoreService),
      ),
    );
  }

  Future<void> _confirmSignOut(AuthProvider authProvider) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text(
          'Oturumunuzu kapatıp giriş ekranına dönmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusError,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !mounted) return;
    await authProvider.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginView()),
      (_) => false,
    );
  }

  void _openReportSheet(WasteReportModel report) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportCardSheet(
        report: report,
        firestoreService: _firestoreService,
        onShowOnMap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => WasteMapView(focusedReport: report),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AuthProvider? authProvider;
    ThemeProvider? themeProvider;
    try {
      authProvider = context.watch<AuthProvider>();
    } catch (_) {}
    try {
      themeProvider = context.watch<ThemeProvider>();
    } catch (_) {}

    final user = authProvider?.userModel ??
        UserModel(
          uid: 'demo_user_1',
          fullName: 'Çevre Gönüllüsü',
          email: 'gonullu@ecotrack.org',
          level: 'Fidan',
          createdAt: DateTime.now(),
        );

    _syncReportsStream(user.uid);
    final badges = _buildBadges(user);
    final unlockedCount = badges.where((b) => b.isUnlocked).length;
    final bottomPadding = widget.hasFloatingNavBar
        ? 110.0 + MediaQuery.paddingOf(context).bottom
        : 24.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Profil & Başarımlar'),
        actions: [
          if (themeProvider != null)
            IconButton(
              tooltip: themeProvider.isDarkMode
                  ? 'Aydınlık Moda Geç'
                  : 'Karanlık Moda Geç',
              onPressed: () => themeProvider?.toggleTheme(),
              icon: Icon(
                themeProvider.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: themeProvider.isDarkMode
                    ? AppColors.rankGold
                    : AppColors.primarySage,
              ),
            ),
          IconButton(
            tooltip: 'Liderlik Tablosu',
            onPressed: _openLeaderboard,
            icon: const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.rankGold,
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Kullanıcı Kartı & Seviye İlerlemesi
              _buildProfileCard(
                user: user,
                canEdit: authProvider != null,
                onEditTap: () => _showEditProfileDialog(authProvider, user),
              ),
              const SizedBox(height: 16),

              // 2. Liderlik Tablosu Erişim Kartı
              _buildLeaderboardBanner(),
              const SizedBox(height: 12),

              // 2.1 Tema Değiştirme Kartı
              _buildThemeSelectorCard(themeProvider),
              const SizedBox(height: 20),

              // 3. Rozetler Bölümü
              Text(
                'Kazanılan Rozetler ($unlockedCount/${badges.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 12),
              _buildBadgesWrap(badges),
              const SizedBox(height: 24),

              // 4. Kullanıcının İhbarları
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Açtığım İhbarlar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CreateReportView(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_location_alt_outlined, size: 17),
                    label: const Text('Yeni İhbar'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<WasteReportModel>>(
                stream: _userReportsStream,
                builder: (context, snapshot) {
                  final reports = snapshot.data ?? const <WasteReportModel>[];
                  if (reports.isEmpty) {
                    return SurfaceCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.campaign_outlined,
                            size: 34,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Henüz oluşturduğunuz bir ihbar bulunmuyor.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: reports.map((report) {
                      final isPending = report.status == 'pending';
                      final statusColor = isPending
                          ? AppColors.statusPending
                          : AppColors.primaryLight;
                      final dateText = DateFormat('dd.MM.yyyy HH:mm')
                          .format(report.createdAt);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SurfaceCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            onTap: () => _openReportSheet(report),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surfaceSubtleOf(context),
                              child: Icon(
                                isPending
                                    ? Icons.delete_outline
                                    : Icons.check_circle_outline,
                                color: statusColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              report.wasteType,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            subtitle: Text(
                              '${report.addressText}\n$dateText',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusPill(
                                  label: isPending ? 'Bekliyor' : 'Temizlendi',
                                  color: statusColor,
                                  fontSize: 11,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  tooltip: 'İhbarı Sil',
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  onPressed: () => confirmAndDeleteWasteReport(
                                    context,
                                    report: report,
                                    firestoreService: _firestoreService,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                    color: AppColors.statusError,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              // 5. Çıkış Yap Butonu
              if (authProvider != null) ...[
                const SizedBox(height: 28),
                Tooltip(
                  message: 'Çıkış Yap',
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmSignOut(authProvider!),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    label: const Text(
                      'Çıkış Yap',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusError,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required UserModel user,
    required bool canEdit,
    required VoidCallback onEditTap,
  }) {
    final points = user.ecoPoints;
    final String nextLevelLabel;
    final double progress;
    if (points >= 200) {
      nextLevelLabel = 'Maksimum seviyeye ulaştınız!';
      progress = 1.0;
    } else if (points >= 80) {
      nextLevelLabel = 'Çevre Kahramanı için ${200 - points} puan kaldı';
      progress = (points - 80) / 120.0;
    } else {
      nextLevelLabel = 'Doğa Dostu için ${80 - points} puan kaldı';
      progress = points / 80.0;
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: canEdit ? onEditTap : null,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.surfaceSubtle,
                        foregroundColor: AppColors.primaryLight,
                        backgroundImage: (user.photoUrl != null &&
                                user.photoUrl!.trim().isNotEmpty)
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        onBackgroundImageError: (user.photoUrl != null &&
                                user.photoUrl!.trim().isNotEmpty)
                            ? (_, __) {}
                            : null,
                        child: (user.photoUrl != null &&
                                user.photoUrl!.trim().isNotEmpty)
                            ? null
                            : Text(
                                _initials(user.fullName),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      if (canEdit)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.primarySage,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
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
                            user.fullName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (canEdit)
                          IconButton(
                            tooltip: 'Adı Düzenle',
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.textSecondaryOf(context),
                            ),
                            onPressed: onEditTap,
                          ),
                      ],
                    ),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '“${user.bio!.trim()}”',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if ((user.city != null && user.city!.trim().isNotEmpty) ||
                        (user.phoneNumber != null &&
                            user.phoneNumber!.trim().isNotEmpty)) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        children: [
                          if (user.city != null && user.city!.trim().isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  user.city!.trim(),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          if (user.phoneNumber != null &&
                              user.phoneNumber!.trim().isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 13,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  user.phoneNumber!.trim(),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    StatusPill(
                      label: user.level,
                      icon: Icons.verified_outlined,
                      color: AppColors.primaryLight,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.surfaceSubtleOf(context),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primarySage),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              nextLevelLabel,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _ProfileStatCell(
                label: 'Eco-Puan',
                value: '${user.ecoPoints}',
              ),
              _ProfileStatCell(
                label: 'Geri Dönüşüm',
                value: '${user.recycledCount}',
              ),
              _ProfileStatCell(
                label: 'İhbar',
                value: '${user.reportCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelectorCard(ThemeProvider? themeProvider) {
    if (themeProvider == null) return const SizedBox.shrink();
    final isDark = themeProvider.isDarkMode;

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceSubtle : AppColors.surfaceSubtleLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.surfaceBorder : AppColors.surfaceBorderLight,
              ),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: isDark ? AppColors.rankGold : AppColors.primarySage,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDark ? 'Karanlık Mod' : 'Aydınlık Mod',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark
                      ? 'Göz yormayan minimalist koyu tema'
                      : 'Ferah ve aydınlık minimalist tema',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: !isDark,
            activeTrackColor: AppColors.primarySage,
            onChanged: (_) => themeProvider.toggleTheme(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardBanner() {
    return SurfaceCard(
      onTap: _openLeaderboard,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtleOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorderOf(context)),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.rankGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liderlik Tablosunu Gör',
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'En yüksek puanlı ilk 20 doğa gönüllüsü',
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondaryOf(context),
          ),
        ],
      ),
    );
  }

  List<_EcoBadge> _buildBadges(UserModel user) {
    return [
      _EcoBadge(
        title: 'İlk Adım',
        description: 'İlk atığını tara',
        icon: Icons.eco_outlined,
        isUnlocked: user.recycledCount >= 1 || user.ecoPoints >= 10,
      ),
      _EcoBadge(
        title: 'Çevre Gözcüsü',
        description: 'İlk saha ihbarını aç',
        icon: Icons.add_location_alt_outlined,
        isUnlocked: user.reportCount >= 1,
      ),
      _EcoBadge(
        title: 'Doğa Dostu',
        description: '80 Eco-Puan\'a ulaş',
        icon: Icons.park_outlined,
        isUnlocked: user.ecoPoints >= 80,
      ),
      _EcoBadge(
        title: 'Geri Dönüşüm Ustası',
        description: '10 atık dönüştür',
        icon: Icons.recycling_rounded,
        isUnlocked: user.recycledCount >= 10,
      ),
      _EcoBadge(
        title: 'Çevre Kahramanı',
        description: '200 Eco-Puan\'a ulaş',
        icon: Icons.workspace_premium_outlined,
        isUnlocked: user.ecoPoints >= 200,
      ),
    ];
  }

  Widget _buildBadgesWrap(List<_EcoBadge> badges) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: badges.map((badge) {
        const unlockedColor = AppColors.primaryLight;
        final iconColor =
            badge.isUnlocked ? unlockedColor : AppColors.textMuted;

        return Opacity(
          opacity: badge.isUnlocked ? 1.0 : 0.55,
          child: Container(
            width: 155,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: badge.isUnlocked
                  ? AppColors.surfaceOf(context)
                  : AppColors.bgPrimaryOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: badge.isUnlocked
                    ? AppColors.primarySage.withValues(alpha: 0.7)
                    : AppColors.surfaceBorderOf(context),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(badge.icon, color: iconColor, size: 22),
                    Icon(
                      badge.isUnlocked
                          ? Icons.check_circle_outline
                          : Icons.lock_outline,
                      size: 16,
                      color: iconColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  badge.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: badge.isUnlocked
                        ? AppColors.textPrimaryOf(context)
                        : AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge.description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProfileStatCell extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStatCell({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _EcoBadge {
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;

  const _EcoBadge({
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });
}

class _EditProfileDialog extends StatefulWidget {
  final UserModel user;
  final AuthProvider authProvider;
  final StorageService storageService;

  const _EditProfileDialog({
    required this.user,
    required this.authProvider,
    required this.storageService,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;
  late final TextEditingController _newPassController;
  late final TextEditingController _confirmPassController;

  File? _selectedImage;
  Uint8List? _selectedBytes;
  bool _removePhoto = false;
  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _cityController = TextEditingController(text: widget.user.city ?? '');
    _phoneController = TextEditingController(text: widget.user.phoneNumber ?? '');
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _newPassController = TextEditingController();
    _confirmPassController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImage = File(picked.path);
          _selectedBytes = bytes;
          _removePhoto = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf seçilemedi: $e'),
          backgroundColor: AppColors.statusError,
        ),
      );
    }
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad Soyad boş bırakılamaz.'),
          backgroundColor: AppColors.statusError,
        ),
      );
      return;
    }

    final newPass = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();
    if (newPass.isNotEmpty) {
      if (newPass.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yeni şifre en az 6 karakter olmalıdır.'),
            backgroundColor: AppColors.statusError,
          ),
        );
        return;
      }
      if (newPass != confirmPass) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifreler birbiriyle uyuşmuyor.'),
            backgroundColor: AppColors.statusError,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      String? photoUrl;
      bool clearPhoto = false;

      if (_removePhoto) {
        clearPhoto = true;
      } else if (_selectedBytes != null && _selectedBytes!.isNotEmpty) {
        if (!kIsWeb && _selectedImage != null) {
          photoUrl = await widget.storageService.uploadProfileImage(
            _selectedImage!,
            userId: widget.user.uid,
          );
        } else {
          photoUrl = await widget.storageService.uploadProfileBytes(
            _selectedBytes!,
            userId: widget.user.uid,
          );
        }
      }

      final success = await widget.authProvider.updateProfileDetails(
        fullName: newName,
        photoUrl: photoUrl ?? (_removePhoto ? null : widget.user.photoUrl),
        clearPhotoUrl: clearPhoto,
        city: _cityController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        newPassword: newPass.isNotEmpty ? newPass : null,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Profil adınız güncellendi.'),
            backgroundColor: AppColors.surface,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.authProvider.errorMessage ?? 'Profil güncellenemedi.',
            ),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Hata oluştu: $e'),
          backgroundColor: AppColors.statusError,
        ),
      );
    }
  }

  Widget _buildPhotoSection() {
    ImageProvider? imageProvider;
    if (_removePhoto) {
      imageProvider = null;
    } else if (_selectedBytes != null && _selectedBytes!.isNotEmpty) {
      imageProvider = MemoryImage(_selectedBytes!);
    } else if (widget.user.photoUrl != null &&
        widget.user.photoUrl!.trim().isNotEmpty) {
      imageProvider = NetworkImage(widget.user.photoUrl!);
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.surfaceSubtleOf(context),
              foregroundColor: AppColors.primaryLight,
              backgroundImage: imageProvider,
              onBackgroundImageError: imageProvider != null ? (_, __) {} : null,
              child: imageProvider == null
                  ? Text(
                      _initials(
                        _nameController.text.isNotEmpty
                            ? _nameController.text
                            : widget.user.fullName,
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 15),
              label: const Text('Kamera', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 15),
              label: const Text('Galeri', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            if (imageProvider != null)
              TextButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _selectedImage = null;
                          _selectedBytes = null;
                          _removePhoto = true;
                        });
                      },
                icon: const Icon(Icons.delete_outline,
                    size: 15, color: AppColors.statusError),
                label: const Text(
                  'Kaldır',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.statusError),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.surfaceBorderOf(context)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profil Adını Düzenle',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textSecondaryOf(context),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.surfaceBorderOf(context)),

            // Kaydırılabilir İçerik
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profil Fotoğrafı
                    _buildPhotoSection(),
                    const SizedBox(height: 18),

                    // Ad Soyad
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        hintText: 'Örn: Emirhan Sapmaz',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Şehir
                    TextField(
                      controller: _cityController,
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: const InputDecoration(
                        labelText: 'Şehir / İlçe',
                        hintText: 'Örn: İstanbul, Kadıköy',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Telefon
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: const InputDecoration(
                        labelText: 'Telefon Numarası',
                        hintText: 'Örn: +90 555 123 4567',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Biyografi / Doğa Notu
                    TextField(
                      controller: _bioController,
                      maxLines: 2,
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: const InputDecoration(
                        labelText: 'Biyografi / Doğa Notu',
                        hintText: 'Doğa için küçük, gelecek için büyük adım...',
                        prefixIcon: Icon(Icons.eco_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Şifre Değiştirme Başlığı
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtleOf(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceBorderOf(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Şifre Değiştir (İsteğe Bağlı)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Yeni Şifre
                    TextField(
                      controller: _newPassController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        labelText: 'Yeni Şifre',
                        hintText: 'En az 6 karakter',
                        prefixIcon:
                            const Icon(Icons.lock_reset_outlined, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Yeni Şifre Tekrar
                    TextField(
                      controller: _confirmPassController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      decoration: const InputDecoration(
                        labelText: 'Yeni Şifre (Tekrar)',
                        hintText: 'Şifrenizi tekrar girin',
                        prefixIcon:
                            Icon(Icons.check_circle_outline, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: AppColors.surfaceBorderOf(context)),

            // Aksiyon Butonları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 42),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Kaydet'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
