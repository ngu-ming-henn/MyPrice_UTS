import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../core/utils/format.dart';
import '../l10n/strings.dart';

/// Single-series column chart of an amount per day (sales or profit): one
/// colour, no legend (the title names it), hairline solid grid, bars at most
/// 24px with 4px rounded ends. Days below zero (a loss) go down, in red.
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({super.key, required this.data});
  final List<({DateTime day, int sen, int orders})> data;

  /// A clean tick step (1, 2 or 5 × 10^n) giving about 4 gridlines.
  static double _niceStep(double max) {
    if (max <= 0) return 10;
    final raw = max / 4;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    for (final m in [1, 2, 5, 10]) {
      if (raw <= m * magnitude) return m * magnitude;
    }
    return 10 * magnitude;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurfaceVariant;
    final grid = theme.colorScheme.onSurface.withValues(alpha: 0.1);
    final maxRM = data.fold(0, (m, d) => math.max(m, d.sen)) / 100;
    final minRM = data.fold(0, (m, d) => math.min(m, d.sen)) / 100;
    final step = _niceStep(maxRM - minRM);
    final maxY = math.max(step, (maxRM / step).ceil() * step);
    final minY = minRM < 0 ? (minRM / step).floor() * step : 0.0;
    final weekly = data.length <= 7;
    final tickStyle = theme.textTheme.labelSmall?.copyWith(
      color: ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = (constraints.maxWidth - 48) / data.length;
        final barWidth = math.min(24.0, slot * 0.6);
        return BarChart(
          BarChartData(
            minY: minY,
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(
              show: true,
              border: Border(bottom: BorderSide(color: grid, width: 1)),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: grid, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: step,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      NumberFormat.compact().format(value),
                      style: tickStyle,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    final last = data.length - 1;
                    // 7 days: every day. 30 days: every 5th day + today.
                    if (!weekly && i != last && (last - i) % 5 != 0) {
                      return const SizedBox.shrink();
                    }
                    final day = data[i].day;
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        weekly
                            ? dateFormat('EEE').format(day)
                            : dateFormat('d/M').format(day),
                        style: tickStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF263238),
                tooltipBorderRadius: BorderRadius.circular(8),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final d = data[group.x];
                  // Value leads, label follows.
                  return BarTooltipItem(
                    formatRM(d.sen),
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(
                        text:
                            '\n${dateFormat('EEE, d MMM').format(d.day)} · '
                            '${context.tr('{count} orders', {'count': d.orders})}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].sen / 100,
                      color: data[i].sen < 0 ? AppColors.error : context.brand,
                      width: barWidth,
                      borderRadius: data[i].sen < 0
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(4),
                            )
                          : const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
