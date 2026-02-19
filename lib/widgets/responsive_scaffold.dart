import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class NavItem {
  final IconData icon;
  final String labelEn;
  final String labelAr;
  const NavItem(this.icon, this.labelEn, this.labelAr);
}

const List<NavItem> navItems = [
  NavItem(Icons.dashboard_rounded, 'Dashboard', 'الرئيسية'),
  NavItem(Icons.apartment_rounded, 'Units', 'الوحدات'),
  NavItem(Icons.calendar_month_rounded, 'Calendar', 'التقويم'),
  NavItem(Icons.smart_toy_rounded, 'Simsar', 'سمسار'),
  NavItem(Icons.book_rounded, 'Bookings', 'الحجوزات'),
  NavItem(Icons.edit_note_rounded, 'Content', 'المحتوى'),
  NavItem(Icons.publish_rounded, 'Publishing', 'النشر'),
  NavItem(Icons.price_change_rounded, 'Rates', 'الأسعار'),
  NavItem(Icons.receipt_long_rounded, 'Expenses', 'المصروفات'),
  NavItem(Icons.account_balance_wallet_rounded, 'Payouts', 'المدفوعات'),
  NavItem(Icons.bar_chart_rounded, 'Reports', 'التقارير'),
  NavItem(Icons.notifications_rounded, 'Notes', 'الملاحظات'),
  NavItem(Icons.settings_rounded, 'Settings', 'الإعدادات'),
];

class ResponsiveScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavChanged;
  final Widget body;
  final bool isRtl;

  const ResponsiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onNavChanged,
    required this.body,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = AppTheme.isMobile(context);
    final isTablet = AppTheme.isTablet(context);

    if (isMobile) {
      return Scaffold(
        body: SafeArea(child: body),
        bottomNavigationBar: _buildBottomNav(context),
        drawer: _buildDrawer(context),
      );
    }

    return Scaffold(
      body: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        children: [
          _buildSidebar(context, expanded: !isTablet),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {bool expanded = true}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: expanded ? 220 : 72,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: isRtl ? BorderSide.none : const BorderSide(color: AppTheme.border),
          left: isRtl ? const BorderSide(color: AppTheme.border) : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home_work_rounded,
                      color: Colors.white, size: 20),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  const Text(
                    'PMS Lite',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (ctx, i) {
                final item = navItems[i];
                final selected = i == currentIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: selected
                        ? AppTheme.accent.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onNavChanged(i),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: expanded ? 12 : 0,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: expanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: selected
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                            ),
                            if (expanded) ...[
                              const SizedBox(width: 10),
                              Text(
                                isRtl ? item.labelAr : item.labelEn,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppTheme.accent
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    // Show first 4 items + "More" button that opens a sheet with all items
    final bottomItems = navItems.take(4).toList();
    final moreSelected = currentIndex >= 4;
    return BottomNavigationBar(
      currentIndex: currentIndex < 4 ? currentIndex : 4,
      onTap: (i) {
        if (i < 4) {
          onNavChanged(i);
        } else {
          _showMoreSheet(context);
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.accent,
      unselectedItemColor: AppTheme.textSecondary,
      selectedFontSize: 10,
      unselectedFontSize: 10,
      items: [
        ...bottomItems.map((item) => BottomNavigationBarItem(
              icon: Icon(item.icon, size: 22),
              label: isRtl ? item.labelAr : item.labelEn,
            )),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz_rounded, size: 22,
              color: moreSelected ? AppTheme.accent : null),
          label: isRtl ? 'المزيد' : 'More',
        ),
      ],
    );
  }

  void _showMoreSheet(BuildContext context) {
    final moreItems = navItems.sublist(4);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(moreItems.length, (i) {
              final item = moreItems[i];
              final realIndex = i + 4;
              final selected = realIndex == currentIndex;
              return ListTile(
                leading: Icon(item.icon,
                    color: selected ? AppTheme.accent : AppTheme.textSecondary),
                title: Text(
                  isRtl ? item.labelAr : item.labelEn,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppTheme.accent : AppTheme.textPrimary,
                  ),
                ),
                selected: selected,
                selectedTileColor: AppTheme.accent.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () {
                  Navigator.pop(ctx);
                  onNavChanged(realIndex);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home_work_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'PMS Lite',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: navItems.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (ctx, i) {
                  final item = navItems[i];
                  final selected = i == currentIndex;
                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: selected ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                    title: Text(
                      isRtl ? item.labelAr : item.labelEn,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? AppTheme.accent : AppTheme.textPrimary,
                      ),
                    ),
                    selected: selected,
                    selectedTileColor: AppTheme.accent.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onNavChanged(i);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
