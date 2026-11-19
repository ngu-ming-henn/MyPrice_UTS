import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/restock_plan.dart';
import '../../viewmodels/staff/restock_view_model.dart';
import '../../widgets/common.dart';
import '../../widgets/product_widgets.dart';

/// Restock plan: what to order before the supplier comes again, learnt from
/// the closed days and the Campus calendar ([RestockViewModel]). The owner
/// adjusts the amounts and sends the list on WhatsApp.
class RestockScreen extends StatelessWidget {
  const RestockScreen({super.key});

  Future<void> _send(BuildContext context) async {
    final message = context.read<RestockViewModel>().orderMessage();
    // No number: WhatsApp asks which contact (the supplier) to send it to.
    final ok = await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: message));
      if (context.mounted) {
        showSnack(
          context,
          context.tr('WhatsApp did not open. The order list is copied.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RestockViewModel>();
    final theme = Theme.of(context);
    final plan = vm.plan;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Restock plan')),
        actions: [
          IconButton(
            tooltip: context.tr('Campus calendar'),
            icon: const Icon(Icons.calendar_month),
            onPressed: () => context.push('/staff/calendar'),
          ),
        ],
      ),
      body: vm.error != null
          ? ErrorView(error: vm.error!)
          : vm.loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _PlanHeader(plan: plan),
                const SizedBox(height: 8),
                if (plan.lines.isEmpty)
                  EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: context.tr('Nothing to order'),
                    message: context.tr(
                      'There is enough stock for the next {days} days.',
                      {'days': AppRules.restockCoverDays},
                    ),
                  )
                else
                  for (final line in plan.lines)
                    _RestockCard(
                      line: line,
                      qty: vm.qtyFor(line),
                      specialType: plan.specialType,
                    ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Enough for the next {days} days plus the low-stock level. '
                    'Pre-orders waiting to be packed are taken off the stock.',
                    {'days': AppRules.restockCoverDays},
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
      floatingActionButton: vm.loading || vm.orderCount == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _send(context),
              icon: const Icon(Icons.send),
              label: Text(
                context.tr('Send {count} items on WhatsApp', {
                  'count': vm.orderCount,
                }),
              ),
            ),
    );
  }
}

/// What the forecast is based on, and the special week coming up.
class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan});
  final RestockPlan plan;

  @override
  Widget build(BuildContext context) {
    final special = plan.specialType;
    final from = plan.specialFrom;
    return Card(
      color: special == null ? null : context.colors.secondaryContainer,
      child: ListTile(
        leading: Icon(
          special == null ? Icons.auto_graph : Icons.event_note,
          color: context.brand,
        ),
        title: Text(
          special == null || from == null
              ? context.tr('Normal weeks ahead')
              : context.tr('{week} from {date}', {
                  'week': context.tr(WeekType.label(special)),
                  'date': dateFormat('EEE d MMM').format(from),
                }),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          plan.hasHistory
              ? context.tr(
                  'Forecast from {days} closed days of sales, by kind of '
                  'campus week.',
                  {'days': plan.historyDays},
                )
              : context.tr(
                  'No sales history yet: close the shop every day to build '
                  'it. Until then, only low-stock items are listed.',
                ),
        ),
      ),
    );
  }
}

class _RestockCard extends StatelessWidget {
  const _RestockCard({
    required this.line,
    required this.qty,
    required this.specialType,
  });
  final RestockLine line;
  final int qty;
  final String? specialType;

  /// "+60% in exam weeks" (compared with normal weeks).
  String _changeLabel(BuildContext context, int change) {
    final args = {'pct': change > 0 ? '+$change' : '$change'};
    return switch (specialType) {
      WeekType.exam => context.tr('{pct}% in exam weeks', args),
      WeekType.semesterBreak => context.tr('{pct}% in semester breaks', args),
      _ => context.tr('{pct}% in event weeks', args),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.read<RestockViewModel>();
    final daysLeft = line.daysLeft;
    final urgent = daysLeft != null && daysLeft < 2;
    final change = line.specialChangePct;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.product.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    daysLeft == null
                        ? context.tr('{stock} in stock · not selling lately', {
                            'stock': line.available,
                          })
                        : context.tr(
                            '{stock} in stock · sells {rate}/day · '
                            '{days} days left',
                            {
                              'stock': line.available,
                              'rate': line.perDay.toStringAsFixed(1),
                              'days': daysLeft.toStringAsFixed(1),
                            },
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: urgent ? AppColors.error : null,
                      fontWeight: urgent ? FontWeight.w600 : null,
                    ),
                  ),
                  if (change != null && change != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Pill(
                        label: _changeLabel(context, change),
                        color: change > 0 ? context.eco : AppColors.warning,
                        icon: change > 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                      ),
                    ),
                ],
              ),
            ),
            QtyStepper(
              value: qty,
              min: 0,
              onChanged: (v) => vm.setQty(line.product.barcode, v),
            ),
          ],
        ),
      ),
    );
  }
}
