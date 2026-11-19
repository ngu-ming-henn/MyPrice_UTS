import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils/format.dart';
import '../l10n/strings.dart';
import '../models/money.dart';
import 'common.dart';

/// "Cash matches ✓", "Short RM 2.40" or "Over RM 1.00" for a closed day.
/// [compact] (for list rows): a green tick, or just the difference.
class CashCheckPill extends StatelessWidget {
  const CashCheckPill({super.key, required this.closing, this.compact = false});
  final DayClosing closing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final diff = closing.differenceSen;
    if (compact) {
      if (diff == 0) {
        return Icon(
          Icons.check_circle,
          color: context.eco,
          semanticLabel: context.tr('Cash matches ✓'),
        );
      }
      return Text(
        diff < 0 ? formatRM(diff) : '+${formatRM(diff)}',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: diff < 0 ? AppColors.error : AppColors.warning,
        ),
      );
    }
    if (diff == 0) {
      return Pill(
        label: context.tr('Cash matches ✓'),
        color: context.eco,
        icon: Icons.check_circle_outline,
      );
    }
    return Pill(
      label: diff < 0
          ? context.tr('Short {amount}', {'amount': formatRM(-diff)})
          : context.tr('Over {amount}', {'amount': formatRM(diff)}),
      color: diff < 0 ? AppColors.error : AppColors.warning,
      icon: diff < 0 ? Icons.error_outline : Icons.info_outline,
    );
  }
}

/// One label / amount line.
class MoneyRow extends StatelessWidget {
  const MoneyRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              fontWeight: bold ? FontWeight.w700 : null,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// A saved day: sales and profit, then the cash check.
class ClosingSummaryCard extends StatelessWidget {
  const ClosingSummaryCard({super.key, required this.closing});
  final DayClosing closing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = closing;
    final diff = c.differenceSen;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateFormat('EEEE, d MMM yyyy').format(c.day),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (c.sample)
                  Pill(label: context.tr('Sample'), color: Colors.blueGrey),
              ],
            ),
            if (c.closedAt != null)
              Text(
                context.tr('Closed at {time}', {
                  'time': formatTime(c.closedAt!),
                }),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: CashCheckPill(closing: c),
            ),
            const Divider(height: 24),
            MoneyRow(
              label: context.tr('Sales ({count} orders)', {
                'count': c.orderCount,
              }),
              value: formatRM(c.salesSen),
              bold: true,
            ),
            MoneyRow(label: context.tr('Cost'), value: formatRM(c.costSen)),
            MoneyRow(
              label: context.tr('Profit'),
              value: formatRM(c.profitSen),
              bold: true,
              color: c.profitSen < 0 ? AppColors.error : context.eco,
            ),
            MoneyRow(
              label: context.tr('Thrown away (at cost)'),
              value: formatRM(c.wasteSen),
            ),
            MoneyRow(
              label: context.tr('Saved by Save Food'),
              value: formatRM(c.saveFoodSen),
            ),
            const Divider(height: 24),
            Text(
              context.tr('Cash check'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            MoneyRow(
              label: context.tr('Cash at opening (float)'),
              value: formatRM(c.floatSen),
            ),
            MoneyRow(
              label: context.tr('Cash sales'),
              value: formatRM(c.cashSen),
            ),
            MoneyRow(
              label: context.tr('Expected in drawer'),
              value: formatRM(c.expectedCashSen),
              bold: true,
            ),
            MoneyRow(
              label: context.tr('Counted'),
              value: formatRM(c.countedSen),
              bold: true,
            ),
            MoneyRow(
              label: context.tr('Difference'),
              value: diff > 0 ? '+${formatRM(diff)}' : formatRM(diff),
              bold: true,
              color: diff < 0
                  ? AppColors.error
                  : diff > 0
                  ? AppColors.warning
                  : context.eco,
            ),
            MoneyRow(
              label: context.tr('DuitNow QR (in the bank)'),
              value: formatRM(c.qrSen),
            ),
          ],
        ),
      ),
    );
  }
}
