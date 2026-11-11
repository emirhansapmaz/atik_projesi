import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class LeaderboardView extends StatefulWidget {
  final FirestoreService? firestoreService;
  final UserModel? currentUserOverride;

  const LeaderboardView({
    super.key,
    this.firestoreService,
    this.currentUserOverride,
  });

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  late final FirestoreService _firestoreService;
  late Stream<List<UserModel>> _leaderboardStream;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _leaderboardStream = _firestoreService.getLeaderboardStream();
  }

  UserModel? _resolveCurrentUser(BuildContext context) {
    if (widget.currentUserOverride != null) {
      return widget.currentUserOverride;
    }
    try {
      return context.watch<AuthProvider>().userModel;
    } catch (_) {
      return null;
    }
  }

  List<UserModel> _mergeAndSortUsers(
    List<UserModel> streamUsers,
    UserModel? currentUser,
  ) {
    final merged = List<UserModel>.from(streamUsers);
    if (currentUser != null) {
      final idx = merged.indexWhere((u) => u.uid == currentUser.uid);
      if (idx == -1) {
        merged.add(currentUser);
      } else if (currentUser.ecoPoints > merged[idx].ecoPoints ||
          currentUser.fullName != merged[idx].fullName) {
        merged[idx] = currentUser;
      }
    }
    merged.sort((a, b) => b.ecoPoints.compareTo(a.ecoPoints));
    return merged.take(20).toList();
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

  Color? _topRankColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.rankGold;
      case 2:
        return AppColors.rankSilver;
      case 3:
        return AppColors.rankBronze;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _resolveCurrentUser(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Liderlik Tablosu'),
      ),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<UserModel>>(
          stream: _leaderboardStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryLight),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 44,
                        color: AppColors.statusError,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sıralama yüklenirken hata oluştu: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textPrimaryOf(context)),
                      ),
                    ],
                  ),
                ),
              );
            }

            final rankedUsers = _mergeAndSortUsers(
              snapshot.data ?? const <UserModel>[],
              currentUser,
            );

            if (rankedUsers.isEmpty) {
              return const Center(
                child: Text(
                  'Henüz sıralamada kullanıcı bulunmuyor.',
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
              );
            }

            final currentRankIndex = currentUser == null
                ? -1
                : rankedUsers.indexWhere((u) => u.uid == currentUser.uid);
            final showPinnedSelfCard = currentUser != null &&
                (currentRankIndex == -1 || currentRankIndex >= 3);

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: rankedUsers.length,
                    itemBuilder: (context, index) {
                      final rank = index + 1;
                      final user = rankedUsers[index];
                      final isSelf = currentUser?.uid == user.uid;
                      final rankAccent = _topRankColor(rank);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SurfaceCard(
                          padding: EdgeInsets.zero,
                          color: isSelf
                              ? AppColors.surfaceSubtleOf(context)
                              : AppColors.surfaceOf(context),
                          borderColor: isSelf
                              ? AppColors.primarySage
                              : AppColors.surfaceBorderOf(context),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: rankAccent != null
                                        ? rankAccent.withValues(alpha: 0.14)
                                        : AppColors.surfaceSubtleOf(context),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: rankAccent != null
                                          ? rankAccent.withValues(alpha: 0.45)
                                          : AppColors.surfaceBorderOf(context),
                                    ),
                                  ),
                                  child: Text(
                                    '$rank.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: rankAccent ??
                                          (isSelf
                                              ? AppColors.primaryLight
                                              : AppColors.textSecondaryOf(context)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.surfaceSubtleOf(context),
                                  foregroundColor: rankAccent ??
                                      (isSelf
                                          ? AppColors.primaryLight
                                          : AppColors.textPrimaryOf(context)),
                                  child: Text(
                                    _initials(user.fullName),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              isSelf
                                  ? '${user.fullName} (Sen)'
                                  : user.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              user.level,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtleOf(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.surfaceBorderOf(context),
                                ),
                              ),
                              child: Text(
                                '${user.ecoPoints} Puan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: rankAccent ?? AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (showPinnedSelfCard)
                  _PinnedCurrentUserBar(
                    user: currentUser,
                    rankText: currentRankIndex == -1
                        ? '20+'
                        : '#${currentRankIndex + 1}',
                    initials: _initials(currentUser.fullName),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PinnedCurrentUserBar extends StatelessWidget {
  final UserModel user;
  final String rankText;
  final String initials;

  const _PinnedCurrentUserBar({
    required this.user,
    required this.rankText,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorderOf(context)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySage,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                rankText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              backgroundColor: AppColors.surfaceSubtleOf(context),
              foregroundColor: AppColors.primaryLight,
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sizin Sıranız',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtleOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceBorderOf(context)),
              ),
              child: Text(
                '${user.ecoPoints} Puan',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
