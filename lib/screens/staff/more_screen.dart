import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/staff/more_view_model.dart';
import '../../widgets/common.dart';
import '../../widgets/preferences_card.dart';
import '../../widgets/user_avatar.dart';

/// Staff "More" tab: profile, language and appearance, and links to the
/// other staff tools ([MoreViewModel]).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _seed(BuildContext context) async {
    final vm = context.read<MoreViewModel>();
    final ok = await confirm(
      context,
      title: context.tr('Load sample products?'),
      message: context.tr(
        'Adds {count} demo products (food, drinks, snacks, stationery...) '
        'with stock, expiry dates and descriptions. Existing products keep '
        'their stock and prices.',
        {'count': vm.sampleProductCount},
      ),
      confirmLabel: context.tr('Load'),
      cancelLabel: context.tr('Cancel'),
    );
    if (!ok || !context.mounted) return;
    try {
      final result = await vm.loadSampleProducts();
      if (context.mounted) {
        showSnack(
          context,
          result.added > 0
              ? context.tr('Added {count} products.', {'count': result.added})
              : result.described + result.costed > 0
              ? context.tr('Updated {count} sample products.', {
                  'count': result.described + result.costed,
                })
              : context.tr('Sample products already loaded.'),
        );
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _seedHistory(BuildContext context) async {
    final vm = context.read<MoreViewModel>();
    final ok = await confirm(
      context,
      title: context.tr('Load sample sales history?'),
      message: context.tr(
        'Adds 8 weeks of sample closed days (marked "Sample") and marks a '
        'semester break, an exam week and an event week in the Campus '
        'calendar, plus an exam week next week. Load the sample products '
        'first. Days you closed yourself are kept.',
      ),
      confirmLabel: context.tr('Load'),
      cancelLabel: context.tr('Cancel'),
    );
    if (!ok || !context.mounted) return;
    try {
      final added = await vm.loadSampleHistory();
      if (context.mounted) {
        showSnack(
          context,
          context.tr('Added {count} sample days. Open the Money tab.', {
            'count': added,
          }),
        );
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirm(
      context,
      title: context.tr('Log out?'),
      message: context.tr('You can log in again any time.'),
      confirmLabel: context.tr('Log out'),
    );
    if (ok && context.mounted) await context.read<AuthViewModel>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    Widget tile(
      IconData icon,
      String title,
      String? subtitle,
      VoidCallback onTap, {
      Color? color,
    }) => ListTile(
      leading: Icon(icon, color: color ?? context.brand),
      title: Text(context.tr(title)),
      subtitle: subtitle == null ? null : Text(context.tr(subtitle)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('More'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: UserAvatar(name: user?.name ?? '', photo: user?.photo),
              title: Text(user?.name ?? ''),
              subtitle: Text(
                '${user?.email ?? ''} · ${context.tr('Koperasi staff')}',
              ),
              onTap: () => context.push('/staff/profile'),
            ),
          ),
          const SizedBox(height: 12),
          // Language (English / Bahasa Melayu) and light / dark mode, same
          // as the student Profile.
          const PreferencesCard(),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                tile(
                  Icons.lock_clock,
                  'Close shop',
                  'Count the cash and save the day',
                  () => context.push('/staff/close'),
                ),
                tile(
                  Icons.local_shipping_outlined,
                  'Restock plan',
                  'What to order for the coming week',
                  () => context.push('/staff/restock'),
                ),
                tile(
                  Icons.calendar_month,
                  'Campus calendar',
                  'Mark exam weeks, semester breaks and events',
                  () => context.push('/staff/calendar'),
                ),
                tile(
                  Icons.bar_chart,
                  'Sales & sustainability report',
                  'Sales chart, top products, green impact',
                  () => context.push('/staff/reports'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                tile(
                  Icons.inventory_2_outlined,
                  'Products',
                  'Add, edit, disable',
                  () => context.push('/staff/products'),
                ),
                tile(
                  Icons.point_of_sale,
                  'Counter sale',
                  'Scan items and checkout',
                  () => context.push('/staff/counter'),
                ),
                tile(
                  Icons.notifications_active_outlined,
                  'Alerts',
                  'Low stock, near expiry, Save Food',
                  () => context.push('/staff/alerts'),
                ),
                tile(
                  Icons.qr_code_2,
                  'QR labels',
                  'For items without a barcode',
                  () => context.push('/staff/products'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                tile(
                  Icons.dataset_outlined,
                  'Load sample products',
                  'For testing and the demo',
                  () => _seed(context),
                  color: const Color(0xFF1565C0),
                ),
                tile(
                  Icons.history,
                  'Load sample sales history',
                  'For the Money tab and the restock plan demo',
                  () => _seedHistory(context),
                  color: const Color(0xFF1565C0),
                ),
                tile(
                  Icons.group_add_outlined,
                  'Staff accounts',
                  'Add or remove koperasi staff',
                  () => context.push('/staff/accounts'),
                ),
                tile(
                  Icons.location_on_outlined,
                  'Find the koperasi',
                  'Map, opening hours, directions',
                  () => context.push('/shop'),
                  color: Colors.blueGrey,
                ),
                tile(
                  Icons.info_outline,
                  'About SmartShop',
                  null,
                  () => context.push('/settings'),
                  color: Colors.blueGrey,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: Text(context.tr('Log out')),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
