import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/staff/reports_view_model.dart';
import '../../widgets/common.dart';
import '../../widgets/daily_bar_chart.dart';
import '../../widgets/motion.dart';

/// Sales chart, top products and the sustainability metrics (section 10).
/// Numbers from [ReportsViewModel].
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final report = vm.report;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Reports'))),
      body: vm.error != null
          ? ErrorView(error: vm.error!)
          : report == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // One filter row above everything it scopes.
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 7,
                      label: Text(context.tr('Last 7 days')),
                    ),
                    ButtonSegment(
                      value: 30,
                      label: Text(context.tr('Last 30 days')),
                    ),
                  ],
                  selected: {vm.days},
                  onSelectionChanged: (s) => vm.showDays(s.first),
                ),
                const SizedBox(height: 16),
                // While a new period loads, keep the previous one, dimmed.
                AnimatedOpacity(
                  opacity: vm.refreshing ? 0.5 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: _ReportBody(report: report),
                ),
              ],
            ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = report;
    final big = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final queueTime = r.queueMinutesSaved >= 60
        ? context.tr('{h}h {m}m', {
            'h': r.queueMinutesSaved ~/ 60,
            'm': r.queueMinutesSaved % 60,
          })
        : context.tr('{m} min', {'m': r.queueMinutesSaved});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _Summary(
                    label: context.tr('Sales'),
                    child: Text(formatRM(r.salesSen), style: big),
                  ),
                  const VerticalDivider(width: 1),
                  _Summary(
                    label: context.tr('Orders'),
                    child: CountUp(value: r.orderCount, style: big),
                  ),
                  const VerticalDivider(width: 1),
                  _Summary(
                    label: context.tr('Pre-orders'),
                    child: CountUp(value: r.preorderCount, style: big),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    context.tr('Daily sales (RM)'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    context.tr(
                      'Collected orders. Tap a bar for the exact amount.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                SizedBox(height: 220, child: DailyBarChart(data: r.dailySales)),
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      context.tr('View as table'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    children: [
                      for (final d in r.dailySales.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dateFormat('EEE, d MMM').format(d.day),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  context.tr('{count} orders', {
                                    'count': d.orders,
                                  }),
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  formatRM(d.sen),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SectionHeader(title: context.tr('Top products (units sold)')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: r.topProducts.isEmpty
                ? Text(context.tr('No sales in this period yet.'))
                : _TopProducts(items: r.topProducts),
          ),
        ),
        SectionHeader(title: context.tr('🌱 Sustainability impact')),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GoalBar(
                  label: context.tr('Pre-order share'),
                  percent: r.preorderSharePct,
                  target: 20,
                ),
                const SizedBox(height: 14),
                _GoalBar(
                  label: context.tr('Pre-orders with no plastic bag'),
                  percent: r.preorderNoBagPct,
                  target: 50,
                ),
                const Divider(height: 28),
                _Metric(
                  icon: Icons.timer_outlined,
                  label: context.tr('Shopping time saved by pre-orders'),
                  value: queueTime,
                ),
                _Metric(
                  icon: Icons.receipt_long,
                  label: context.tr('Paper receipts avoided'),
                  value: '${r.receiptsAvoided}',
                ),
                _Metric(
                  icon: Icons.shopping_bag_outlined,
                  label: context.tr('Plastic bags avoided'),
                  value: '${r.bagsAvoided}',
                ),
                _Metric(
                  icon: Icons.bakery_dining,
                  label: context.tr('Items saved from waste (Save Food sold)'),
                  value: '${r.itemsSaved}',
                ),
                _Metric(
                  icon: Icons.remove_shopping_cart_outlined,
                  label: context.tr('Out-of-stock events (aim: down)'),
                  value: '${r.outOfStockEvents}',
                ),
                _Metric(
                  icon: Icons.delete_outline,
                  label: context.tr('Items expired (aim: down)'),
                  value: '${r.itemsExpired}',
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Shopping time assumes {min} minutes saved per collected pre-order. '
                    'Pre-order share counts the transactions recorded in the app.',
                    {'min': AppRules.minutesSavedPerPreorder},
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One number in the summary card.
class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(child: child),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}

/// A percentage against its target: the bar fills up to 100% of the target
/// and turns green once the target is reached.
class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.label,
    required this.percent,
    required this.target,
  });

  final String label;
  final int percent;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = percent >= target;
    final color = reached ? context.eco : AppColors.warning;
    final fill = (percent / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => Container(
            height: 8,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fill),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Container(
                width: c.maxWidth * v,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          reached
              ? context.tr('Target {target}% reached ✓', {'target': target})
              : context.tr('Target {target}%', {'target': target}),
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// One line in the sustainability list: icon, label, number.
class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.eco),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bars built from widgets: one colour, value at the tip.
class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.items});
  final List<({String name, int qty})> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = items.first.qty;
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 16,
                            width: math.max(4, c.maxWidth * item.qty / max),
                            decoration: BoxDecoration(
                              color: context.brand,
                              borderRadius: BorderRadius.horizontal(
                                right: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${item.qty}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
