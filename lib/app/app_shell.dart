import 'package:flutter/material.dart';

import '../features/analytics/analytics_screen.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/auth_user.dart';
import '../features/home/home_screen.dart';
import '../features/scan/scan_hub_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transactions/transaction_repository.dart';
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

class _AppShellState extends State<AppShell> {
  var _selectedTab = AppShellTab.home;

  void _selectTab(AppShellTab tab) {
    if (_selectedTab == tab) {
      return;
    }

    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF3FAFB),
      bottomNavigationBar: _FloatingNavigationBar(
        currentTab: _selectedTab,
        onSelectTab: _selectTab,
      ),
      body: IndexedStack(
        index: _selectedTab.index,
        children: [
          HomeScreen(
            user: widget.user,
            transactionRepository: widget.transactionRepository,
            onOpenScan: () => _selectTab(AppShellTab.scan),
            onOpenSettings: () => _selectTab(AppShellTab.settings),
          ),
          ScanHubScreen(
            user: widget.user,
            transactionRepository: widget.transactionRepository,
            showBackButton: false,
          ),
          AnalyticsScreen(
            user: widget.user,
            transactionRepository: widget.transactionRepository,
          ),
          SettingsScreen(
            user: widget.user,
            authService: widget.authService,
            transactionRepository: widget.transactionRepository,
          ),
        ],
      ),
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

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26305472),
              blurRadius: 24,
              offset: Offset(0, 12),
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
        ? const Color(0xFF145CC8)
        : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
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
