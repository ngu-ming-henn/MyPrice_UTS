import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/money.dart';
import '../../viewmodels/staff/money_view_model.dart';
import '../../widgets/closing_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/daily_bar_chart.dart';

/// Money tab: profit for today / 7 / 30 days, the products that earn the
/// most and the least, waste vs Save Food, how campus weeks compare and the
/// closing history. Numbers from [MoneyViewModel].
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MoneyViewModel>();
    final report = vm.report;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Money')),
        actions: [
          IconButton(
            tooltip: context.tr('Sales & sustainability report'),
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/staff/reports'),
          ),
        ],
      ),
      body: vm.error != null
          ? ErrorView(error: vm.error!)
          : report == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 1, label: Text(context.tr('Today'))),
                    ButtonSegment(value: 7, label: Text(context.tr('7 days'))),
                    ButtonSegment(
                      value: 30,
                      label: Text(context.tr('30 days')),
                    ),
                  ],
                  selected: {vm.days},
                  onSelectionChanged: (s) => vm.showDays(s.first),
                ),
                const SizedBox(height: 16),
                AnimatedOpacity(
                  opacity: vm.refreshing ? 0.5 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: _MoneyBody(vm: vm, report: report),
                ),
              ],
            ),
    );
  }
}

class _MoneyBody extends StatelessWidget {
  const _MoneyBody({required this.vm, required this.report});
  final MoneyViewModel vm;
  final MoneyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = report.totals;
    final big = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final closings = vm.closings;

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
                    child: Text(formatRM(t.salesSen), style: big),
                  ),
                  const VerticalDivider(width: 1),
                  _Summary(
                    label: context.tr('Cost'),
                    child: Text(formatRM(t.costSen), style: big),
                  ),
                  const VerticalDivider(width: 1),
                  _Summary(
                    label: t.marginPct == null
                        ? context.tr('Profit')
                        : context.tr('Profit ({pct}%)', {'pct': t.marginPct}),
                    child: Text(
                      formatRM(t.profitSen),
                      style: big?.copyWith(
                        color: t.profitSen < 0 ? AppColors.error : context.eco,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            context.tr('{count} orders · Cash {cash} · DuitNow QR {qr}', {
              'count': t.orderCount,
              'cash': formatRM(t.cashSen),
              'qr': formatRM(t.qrSen),
            }),
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (t.unitsWithoutCost > 0) ...[
          const SizedBox(height: 12),
          Card(
            color: AppColors.warning.withValues(alpha: 0.1),
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.warning),
              title: Text(
                context.tr(
                  '{count} item(s) sold have no cost price, so the profit '
                  'leaves them out.',
                  {'count': t.unitsWithoutCost},
                ),
              ),
              subtitle: Text(context.tr('Add cost prices in Products.')),
              onTap: () => context.push('/staff/products'),
            ),
          ),
        ],
        if (vm.days > 1) ...[
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
                      context.tr('Daily profit (RM)'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      context.tr(
                        'Sales minus cost price. Tap a bar for the exact amount.',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  SizedBox(
                    height: 200,
                    child: DailyBarChart(data: report.dailyProfit),
                  ),
                ],
              ),
            ),
          ),
        ],
        SectionHeader(title: context.tr('💰 Earns the most')),
        _ProductList(
          items: report.best,
          empty: context.tr('No sales with a cost price in this period yet.'),
        ),
        if (report.worst.isNotEmpty) ...[
          SectionHeader(title: context.tr('Earns the least')),
          _ProductList(items: report.worst, empty: ''),
        ],
        SectionHeader(title: context.tr('🗑️ Waste vs Save Food')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                MoneyRow(
                  label: context.tr('Lost: expired or damaged (at cost)'),
                  value: formatRM(report.wasteSen),
                  color: report.wasteSen > 0 ? AppColors.error : null,
                ),
                MoneyRow(
                  label: context.tr('Saved: sold on Save Food instead'),
                  value: formatRM(t.saveFoodSen),
                  color: context.eco,
                ),
              ],
            ),
          ),
        ),
        SectionHeader(title: context.tr('📅 Campus weeks compared')),
        _WeekComparisonCard(weeks: vm.weeks),
        SectionHeader(
          title: vm.shortDays == 0
              ? context.tr('Closing history')
              : context.tr('Closing history · {count} day(s) short', {
                  'count': vm.shortDays,
                }),
        ),
        if (closings.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_clock),
              title: Text(context.tr('No closed days in this period.')),
              subtitle: Text(
                context.tr('Tap "Close shop" on the Dashboard every evening.'),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final c in closings)
                  ListTile(
                    onTap: () => _showClosing(context, c),
                    title: Text(dateFormat('EEE, d MMM').format(c.day)),
                    subtitle: Text(
                      context.tr('Sales {sales} · Profit {profit}', {
                        'sales': formatRM(c.salesSen),
                        'profit': formatRM(c.profitSen),
                      }),
                    ),
                    trailing: CashCheckPill(closing: c, compact: true),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showClosing(BuildContext context, DayClosing closing) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClosingSummaryCard(closing: closing),
          ),
        ),
      );
}

/// One number in the summary card.
class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          FittedBox(child: child),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
}

/// Products with their units, profit and margin.
class _ProductList extends StatelessWidget {
  const _ProductList({required this.items, required this.empty});
  final List<ProductSales> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(16), child: Text(empty)),
      );
    }
    return Card(
      child: Column(
        children: [
          for (final p in items)
            ListTile(
              dense: true,
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                context.tr('{units} sold · {sales} · margin {pct}%', {
                  'units': p.units,
                  'sales': formatRM(p.salesSen),
                  'pct': p.marginPct ?? 0,
                }),
              ),
              trailing: Text(
                formatRM(p.profitSen!),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.profitSen! < 0 ? AppColors.error : context.eco,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Profit per day for each kind of campus week, against a normal week.
class _WeekComparisonCard extends StatelessWidget {
  const _WeekComparisonCard({required this.weeks});
  final WeekComparison weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (weeks.byType.length < 2) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.calendar_month),
          title: Text(
            context.tr(
              'Mark exam weeks and semester breaks in the Campus calendar, '
              'and close the shop every day, to compare them here.',
            ),
          ),
          onTap: () => context.push('/staff/calendar'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in weeks.byType)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(_weekIcon(s.type), size: 20, color: context.brand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(WeekType.label(s.type)),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            context.tr('{days} days · sales {sales}/day', {
                              'days': s.days,
                              'sales': formatRM(s.salesPerDaySen),
                            }),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          context.tr('{profit}/day', {
                            'profit': formatRM(s.profitPerDaySen),
                          }),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (weeks.changePct(s) != null)
                          Text(
                            context.tr('{pct}% vs normal', {
                              'pct': _signed(weeks.changePct(s)!),
                            }),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: weeks.changePct(s)! < 0
                                  ? AppColors.error
                                  : context.eco,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            Text(
              context.tr('Average profit per open day, from the closed days.'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _signed(int n) => n > 0 ? '+$n' : '$n';

IconData _weekIcon(String type) => switch (type) {
  WeekType.exam => Icons.edit_note,
  WeekType.semesterBreak => Icons.beach_access,
  WeekType.event => Icons.celebration,
  _ => Icons.calendar_view_week,
};
