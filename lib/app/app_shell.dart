import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/analytics/analytics_screen.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/auth_user.dart';
import '../features/home/home_screen.dart';
import '../features/scan/album_sync_background_service.dart';
import '../features/scan/album_sync_review_screen.dart';
import '../features/scan/auto_slip_sync_bridge.dart';
import '../features/scan/scan_hub_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transactions/transaction_repository.dart';
import '../features/transactions/transaction_sync_status.dart';
import '../features/usage/usage_analytics.dart';
import '../shared/widgets/responsive_layout.dart';
import 'app_language.dart';

enum AppShellTab { home, scan, analytics, settings }

class AppShell extends StatefulWidget {
  const AppShell({
    required this.user,
    required this.authService,
    required this.transactionRepository,
    super.key,
  });

  final AuthUser user;
  final AuthService authService;
  final TransactionRepository transactionRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  var _selectedTab = AppShellTab.home;
  StreamSubscription<void>? _albumSyncOpenSubscription;
  StreamSubscription<void>? _autoSyncOpenSubscription;
  bool _isOpeningAlbumSync = false;
  bool _isImportingAutoSync = false;
  var _transitionTick = 0;
  late Stream<TransactionSyncStatus> _syncStatusStream;
  final _loadedTabs = <AppShellTab>{AppShellTab.home};

  @override
  void initState() {
    super.initState();
    _syncStatusStream = widget.transactionRepository.watchSyncStatus(
      widget.user.uid,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(UsageAnalytics.instance.startSession(widget.user.uid));
    _albumSyncOpenSubscription = AlbumSyncBackgroundService.openRequests.listen(
      (_) {
        AlbumSyncBackgroundService.consumeOpenRequest();
        unawaited(_openAlbumSyncFromNotification());
      },
    );
    _autoSyncOpenSubscription = AutoSlipSyncBridge.instance.openRequests.listen(
      (_) => unawaited(_importPendingAutoSync()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AlbumSyncBackgroundService.consumeOpenRequest()) {
        unawaited(_openAlbumSyncFromNotification());
      }
      unawaited(_importPendingAutoSync());
    });
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid ||
        oldWidget.transactionRepository != widget.transactionRepository) {
      _syncStatusStream = widget.transactionRepository.watchSyncStatus(
        widget.user.uid,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    UsageAnalytics.instance.stop();
    _albumSyncOpenSubscription?.cancel();
    _autoSyncOpenSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(UsageAnalytics.instance.heartbeat());
      unawaited(_importPendingAutoSync());
    }
  }

  void _selectTab(AppShellTab tab) {
    if (_selectedTab == tab) {
      return;
    }

    setState(() {
      _loadedTabs.add(tab);
      _selectedTab = tab;
      _transitionTick++;
    });
    unawaited(UsageAnalytics.instance.trackFeature(tab.name));
  }

  Future<void> _openAlbumSyncFromNotification() async {
    if (_isOpeningAlbumSync || !mounted) {
      return;
    }

    final job = await AlbumSyncBackgroundService.loadJob();
    if (job == null || job.userId != widget.user.uid || !mounted) {
      return;
    }

    _isOpeningAlbumSync = true;
    unawaited(UsageAnalytics.instance.trackFeature('album_sync'));
    bool? saved;
    try {
      setState(() {
        _loadedTabs.add(AppShellTab.scan);
        _selectedTab = AppShellTab.scan;
      });
      saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => AlbumSyncReviewScreen(
            user: widget.user,
            transactionRepository: widget.transactionRepository,
            imagePaths: job.imagePaths,
          ),
        ),
      );
    } finally {
      _isOpeningAlbumSync = false;
    }

    if (!mounted) return;
    _selectTab(AppShellTab.home);
    if (saved == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.transactionSaved)));
    }
    unawaited(_importPendingAutoSync());
  }

  Future<void> _importPendingAutoSync() async {
    if (_isImportingAutoSync || !mounted) return;
    _isImportingAutoSync = true;
    try {
      final openRequested = await AutoSlipSyncBridge.instance.takeOpenRequest();
      final existingJob = await AlbumSyncBackgroundService.loadJob();
      if (existingJob != null && existingJob.userId == widget.user.uid) {
        if (openRequested && mounted) {
          await _openAlbumSyncFromNotification();
        }
        return;
      }

      final imagePaths = await AutoSlipSyncBridge.instance.scanNow();
      if (imagePaths.isEmpty || !mounted) return;
      final activeFingerprints = await widget.transactionRepository
          .loadActiveSlipFingerprints(widget.user.uid);
      await AlbumSyncBackgroundService.requestStart(
        userId: widget.user.uid,
        imagePaths: imagePaths,
        activeFingerprints: activeFingerprints,
      );
      await AutoSlipSyncBridge.instance.acknowledge(imagePaths);
      if (openRequested && mounted) {
        await _openAlbumSyncFromNotification();
      }
    } finally {
      _isImportingAutoSync = false;
    }
  }

  Widget _buildTab(AppShellTab tab) {
    if (!_loadedTabs.contains(tab)) return const SizedBox.shrink();

    return switch (tab) {
      AppShellTab.home => HomeScreen(
        user: widget.user,
        transactionRepository: widget.transactionRepository,
        onOpenScan: () => _selectTab(AppShellTab.scan),
        onOpenSettings: () => _selectTab(AppShellTab.settings),
      ),
      AppShellTab.scan => ScanHubScreen(
        user: widget.user,
        transactionRepository: widget.transactionRepository,
        showBackButton: false,
        onReturnHome: () => _selectTab(AppShellTab.home),
      ),
      AppShellTab.analytics => AnalyticsScreen(
        user: widget.user,
        transactionRepository: widget.transactionRepository,
      ),
      AppShellTab.settings => SettingsScreen(
        user: widget.user,
        authService: widget.authService,
        transactionRepository: widget.transactionRepository,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF7F5EF),
      bottomNavigationBar: _FloatingNavigationBar(
        currentTab: _selectedTab,
        onSelectTab: _selectTab,
      ),
      body: Stack(
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(_transitionTick),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(18 * (1 - value), 0),
                child: child,
              ),
            ),
            child: IndexedStack(
              index: _selectedTab.index,
              children: AppShellTab.values.map(_buildTab).toList(),
            ),
          ),
          StreamBuilder<TransactionSyncStatus>(
            stream: _syncStatusStream,
            builder: (context, snapshot) {
              final status =
                  snapshot.data ?? const TransactionSyncStatus.synced();
              return _SyncStatusPill(status: status);
            },
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(SystemNavigator.pop());
      },
      child: scaffold,
    );
  }
}

class _FloatingNavigationBar extends StatelessWidget {
  const _FloatingNavigationBar({
    required this.currentTab,
    required this.onSelectTab,
  });

  final AppShellTab currentTab;
  final ValueChanged<AppShellTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final horizontalMargin = KimjodLayout.isCompact(context) ? 12.0 : 16.0;

    return SafeArea(
      minimum: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 8),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF172826).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0x22FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40172826),
              blurRadius: 24,
              offset: Offset(0, 11),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: strings.home,
              isSelected: currentTab == AppShellTab.home,
              onTap: () => onSelectTab(AppShellTab.home),
            ),
            _NavItem(
              icon: Icons.crop_square_rounded,
              activeIcon: Icons.crop_square_rounded,
              label: strings.scan,
              isSelected: currentTab == AppShellTab.scan,
              onTap: () => onSelectTab(AppShellTab.scan),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              activeIcon: Icons.bar_chart_rounded,
              label: strings.graph,
              isSelected: currentTab == AppShellTab.analytics,
              onTap: () => onSelectTab(AppShellTab.analytics),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              activeIcon: Icons.settings_rounded,
              label: strings.settings,
              isSelected: currentTab == AppShellTab.settings,
              onTap: () => onSelectTab(AppShellTab.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? const Color(0xFF172826)
        : const Color(0xFFB7C4C0);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: isSelected ? 66 : 58,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCFF7E9) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1,
              duration: const Duration(milliseconds: 240),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 19,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusPill extends StatelessWidget {
  const _SyncStatusPill({required this.status});

  final TransactionSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final visible = status.isOffline || status.hasPendingWrites;
    final label = status.hasPendingWrites
        ? (context.strings.isThai
              ? 'รอซิงก์ ${status.pendingWrites} รายการ'
              : '${status.pendingWrites} waiting to sync')
        : (context.strings.isThai
              ? 'กำลังใช้ข้อมูลออฟไลน์'
              : 'Using offline data');

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1.6),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              ignoring: !visible,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 32,
                ),
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF172826),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x30172826),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status.hasPendingWrites
                            ? Icons.cloud_upload_outlined
                            : Icons.cloud_off_outlined,
                        size: 16,
                        color: const Color(0xFFCFF7E9),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
