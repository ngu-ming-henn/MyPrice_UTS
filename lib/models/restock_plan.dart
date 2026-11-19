import '../core/constants.dart';
import '../core/utils/format.dart';
import 'money.dart';
import 'order.dart';
import 'product.dart';

/// One product the restock plan says to order.
class RestockLine {
  const RestockLine({
    required this.product,
    required this.available,
    required this.perDay,
    required this.suggestQty,
    this.normalPerDay,
    this.specialPerDay,
  });

  final Product product;

  /// Stock minus the pre-orders still waiting to be packed.
  final int available;

  /// Expected sales per open day over the coming days.
  final double perDay;

  /// How many to order.
  final int suggestQty;

  /// Sales per day in normal weeks / in the special week coming up.
  final double? normalPerDay;
  final double? specialPerDay;

  /// Open days until it runs out; null when it is not selling.
  double? get daysLeft => perDay <= 0 ? null : available / perDay;

  /// e.g. +60 (%) more sold in exam weeks than in normal weeks.
  int? get specialChangePct {
    final normal = normalPerDay, special = specialPerDay;
    if (normal == null || special == null || normal <= 0) return null;
    return ((special / normal - 1) * 100).round();
  }
}

/// What to order before the supplier comes again (AI restock forecast).
///
/// Sales per day are learnt from the closed days (`closings`), separately
/// for each kind of campus week. The coming [AppRules.restockCoverDays]
/// days are looked up in the Campus calendar, so an exam week coming up
/// uses the sales of past exam weeks. Pre-orders waiting to be packed are
/// taken off the stock, because those items are already promised.
class RestockPlan {
  RestockPlan._({
    required this.lines,
    required this.historyDays,
    this.specialType,
    this.specialFrom,
  });

  /// Products to order, the ones running out first at the top.
  final List<RestockLine> lines;

  /// Closed days the forecast learnt from.
  final int historyDays;

  /// The first exam / break / event week in the coming days, if any.
  final String? specialType;
  final DateTime? specialFrom;

  bool get hasHistory => historyDays > 0;

  factory RestockPlan.build({
    required Iterable<Product> products,
    required Iterable<DayClosing> closings,
    required Map<String, String> weekTypes,
    required Iterable<Order> queue,
    required DateTime today,
    int coverDays = AppRules.restockCoverDays,
  }) {
    // Units sold and open days, per kind of week.
    final days = <String, int>{};
    final units = <String, Map<String, int>>{};
    final allUnits = <String, int>{};
    var historyDays = 0;
    for (final c in closings) {
      if (!dateOnly(c.day).isBefore(dateOnly(today))) continue;
      final type = weekTypeOf(c.day, weekTypes);
      days[type] = (days[type] ?? 0) + 1;
      historyDays++;
      final byProduct = units.putIfAbsent(type, () => {});
      c.unitsByProduct.forEach((id, qty) {
        byProduct[id] = (byProduct[id] ?? 0) + qty;
        allUnits[id] = (allUnits[id] ?? 0) + qty;
      });
    }

    double? rateIn(String type, String productId) {
      final d = days[type] ?? 0;
      return d == 0 ? null : (units[type]?[productId] ?? 0) / d;
    }

    double overallRate(String productId) =>
        historyDays == 0 ? 0 : (allUnits[productId] ?? 0) / historyDays;

    // The coming open days and the kind of week each one is in.
    final coming = [
      for (var i = 1; i <= coverDays; i++)
        DateTime(today.year, today.month, today.day + i),
    ].where((d) => AppRules.openWeekdays.contains(d.weekday)).toList();
    final comingTypes = [for (final d in coming) weekTypeOf(d, weekTypes)];
    final specialIndex = comingTypes.indexWhere((t) => t != WeekType.normal);
    final specialType = specialIndex < 0 ? null : comingTypes[specialIndex];

    // Items promised to pre-orders that are not packed yet.
    final promised = <String, int>{};
    for (final o in queue.where((o) => o.isPending)) {
      for (final i in o.items) {
        promised[i.productId] = (promised[i.productId] ?? 0) + i.qty;
      }
    }

    final lines = <RestockLine>[];
    for (final p in products.where((p) => p.isActive)) {
      var demand = 0.0;
      for (final type in comingTypes) {
        demand += rateIn(type, p.barcode) ?? overallRate(p.barcode);
      }
      final available = p.stock - (promised[p.barcode] ?? 0);
      // Enough for the coming days, plus the low-stock level as a buffer.
      final suggest = demand.ceil() + p.lowStockThreshold - available;
      if (suggest <= 0 || (demand == 0 && !p.needsRestock)) continue;
      lines.add(
        RestockLine(
          product: p,
          available: available,
          perDay: coming.isEmpty ? 0 : demand / coming.length,
          suggestQty: suggest,
          normalPerDay: rateIn(WeekType.normal, p.barcode),
          specialPerDay: specialType == null
              ? null
              : rateIn(specialType, p.barcode),
        ),
      );
    }
    lines.sort((a, b) {
      final x = a.daysLeft, y = b.daysLeft;
      if (x == null || y == null) {
        return x == null && y == null
            ? a.product.name.compareTo(b.product.name)
            : (x == null ? 1 : -1);
      }
      return x.compareTo(y);
    });

    return RestockPlan._(
      lines: lines,
      historyDays: historyDays,
      specialType: specialType,
      specialFrom: specialIndex < 0 ? null : coming[specialIndex],
    );
  }
}
