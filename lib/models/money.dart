import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../core/constants.dart';
import '../core/utils/firestore_helpers.dart';
import '../core/utils/format.dart';
import 'order.dart';
import 'stock_movement.dart';

/// Sales of one product in a period, with its profit when the product has
/// a cost price.
class ProductSales {
  ProductSales(this.productId, this.name);

  final String productId;
  final String name;
  int units = 0;
  int salesSen = 0;

  /// Null when the product has no cost price yet.
  int? costSen;

  int? get profitSen => costSen == null ? null : salesSen - costSen!;

  int? get marginPct => profitSen == null || salesSen == 0
      ? null
      : (profitSen! * 100 / salesSen).round();
}

/// Money taken in a period, added up from collected orders (with the cost
/// prices, staff only in `product_costs`) and from the saved summaries of
/// days already closed. Products without a cost price count as sales but
/// are left out of the profit; [unitsWithoutCost] says how many units.
class SalesTotals {
  SalesTotals._();

  /// From collected orders (other orders are ignored).
  factory SalesTotals.of(Iterable<Order> orders, Map<String, int> costs) =>
      SalesTotals._().._addOrders(orders, costs);

  /// Closed days from their saved summary, the rest from the orders.
  factory SalesTotals.combined({
    required Iterable<Order> orders,
    required Map<String, int> costs,
    required Iterable<DayClosing> closings,
  }) {
    final totals = SalesTotals._().._addOrders(orders, costs);
    for (final c in closings) {
      totals._addClosing(c);
    }
    return totals;
  }

  int _sales = 0;
  int _qr = 0;
  int _orders = 0;
  int _saveFood = 0;
  int _cost = 0;
  int _costedSales = 0;
  int _unitsWithoutCost = 0;
  final _byProduct = <String, ProductSales>{};

  int get salesSen => _sales;

  /// Into the drawer (cash, or paid before the app recorded how).
  int get cashSen => _sales - _qr;

  /// DuitNow QR: straight into the bank.
  int get qrSen => _qr;
  int get orderCount => _orders;

  /// Save Food items sold: money earned instead of throwing them away.
  int get saveFoodSen => _saveFood;

  /// Cost of the units that have a cost price.
  int get costSen => _cost;
  int get unitsWithoutCost => _unitsWithoutCost;
  Map<String, ProductSales> get byProduct => _byProduct;

  /// Sales of the units that have a cost price, minus their cost.
  int get profitSen => _costedSales - _cost;

  int? get marginPct =>
      _costedSales == 0 ? null : (profitSen * 100 / _costedSales).round();

  ProductSales _line(String id, String name) =>
      _byProduct.putIfAbsent(id, () => ProductSales(id, name));

  void _addOrders(Iterable<Order> orders, Map<String, int> costs) {
    for (final o in orders.where((o) => o.isCollected)) {
      _orders++;
      _sales += o.totalSen;
      if (o.paidByQr) _qr += o.totalSen;
      for (final item in o.items) {
        final line = _line(item.productId, item.name);
        line.units += item.qty;
        line.salesSen += item.lineTotalSen;
        if (item.isSaveFood) _saveFood += item.lineTotalSen;
        final unitCost = costs[item.productId];
        if (unitCost == null) {
          _unitsWithoutCost += item.qty;
        } else {
          line.costSen = (line.costSen ?? 0) + unitCost * item.qty;
          _cost += unitCost * item.qty;
          _costedSales += item.lineTotalSen;
        }
      }
    }
  }

  void _addClosing(DayClosing c) {
    _orders += c.orderCount;
    _sales += c.salesSen;
    _qr += c.qrSen;
    _saveFood += c.saveFoodSen;
    _cost += c.costSen;
    _costedSales += c.costSen + c.profitSen;
    _unitsWithoutCost += c.unitsWithoutCost;
    c.products.forEach((id, p) {
      final line = _line(id, p.name);
      line.units += p.units;
      line.salesSen += p.salesSen;
      if (p.costSen != null) line.costSen = (line.costSen ?? 0) + p.costSen!;
    });
  }
}

/// What the stock written off as expired or damaged cost the koperasi.
int wasteCostSen(Iterable<StockMovement> movements, Map<String, int> costs) =>
    movements
        .where(
          (m) =>
              m.type == MovementType.expired || m.type == MovementType.damaged,
        )
        .fold(
          0,
          (total, m) => total + m.quantity.abs() * (costs[m.productId] ?? 0),
        );

/// One product's sales on a closed day.
class ClosingLine {
  const ClosingLine({
    required this.name,
    required this.units,
    required this.salesSen,
    this.costSen,
  });

  final String name;
  final int units;
  final int salesSen;

  /// Null when the product had no cost price.
  final int? costSen;

  factory ClosingLine.fromMap(Map<Object?, Object?> m) => ClosingLine(
    name: m['name'] as String? ?? '',
    units: readInt(m['units']),
    salesSen: readInt(m['salesSen']),
    costSen: readIntOrNull(m['costSen']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'units': units,
    'salesSen': salesSen,
    'costSen': ?costSen,
  };
}

/// A document in `closings/{yyyy-MM-dd}`: the day's summary saved when
/// staff tap "Close shop", with the cash they counted in the drawer. Once a
/// day is closed, the Money tab and the restock plan read this summary
/// instead of all of that day's orders.
class DayClosing {
  const DayClosing({
    required this.day,
    required this.salesSen,
    required this.cashSen,
    required this.qrSen,
    required this.costSen,
    required this.profitSen,
    required this.orderCount,
    required this.wasteSen,
    required this.saveFoodSen,
    required this.floatSen,
    required this.countedSen,
    this.unitsWithoutCost = 0,
    this.products = const {},
    this.closedBy = '',
    this.closedAt,
    this.sample = false,
  });

  /// The day's [totals] with the cash counted in the drawer.
  factory DayClosing.fromTotals({
    required DateTime day,
    required SalesTotals totals,
    required int wasteSen,
    required int floatSen,
    required int countedSen,
    required String closedBy,
  }) => DayClosing(
    day: dateOnly(day),
    salesSen: totals.salesSen,
    cashSen: totals.cashSen,
    qrSen: totals.qrSen,
    costSen: totals.costSen,
    profitSen: totals.profitSen,
    orderCount: totals.orderCount,
    wasteSen: wasteSen,
    saveFoodSen: totals.saveFoodSen,
    floatSen: floatSen,
    countedSen: countedSen,
    unitsWithoutCost: totals.unitsWithoutCost,
    products: {
      for (final p in totals.byProduct.values)
        p.productId: ClosingLine(
          name: p.name,
          units: p.units,
          salesSen: p.salesSen,
          costSen: p.costSen,
        ),
    },
    closedBy: closedBy,
  );

  final DateTime day; // midnight at the start of the day
  final int salesSen;
  final int cashSen;
  final int qrSen;
  final int costSen;
  final int profitSen;
  final int orderCount;
  final int wasteSen;
  final int saveFoodSen;

  /// Cash in the drawer at opening (change for customers).
  final int floatSen;

  /// Cash counted in the drawer at closing.
  final int countedSen;

  /// Units sold that had no cost price (left out of the profit).
  final int unitsWithoutCost;

  /// Sales per product (barcode): the Money tab's product lists and the
  /// restock plan's sales history.
  final Map<String, ClosingLine> products;
  final String closedBy;
  final DateTime? closedAt;

  /// Made by "Load sample sales history" for the demo.
  final bool sample;

  String get id => dayId(day);

  Map<String, int> get unitsByProduct => {
    for (final e in products.entries) e.key: e.value.units,
  };

  int get expectedCashSen => floatSen + cashSen;

  /// Below 0: cash is missing. Above 0: there is more than expected.
  int get differenceSen => countedSen - expectedCashSen;

  bool get cashMatches => differenceSen == 0;
  bool get cashShort => differenceSen < 0;

  factory DayClosing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final products = d['products'];
    return DayClosing(
      day: readDate(d['day']) ?? DateTime.tryParse(doc.id) ?? DateTime(2000),
      salesSen: readInt(d['salesSen']),
      cashSen: readInt(d['cashSen']),
      qrSen: readInt(d['qrSen']),
      costSen: readInt(d['costSen']),
      profitSen: readInt(d['profitSen']),
      orderCount: readInt(d['orderCount']),
      wasteSen: readInt(d['wasteSen']),
      saveFoodSen: readInt(d['saveFoodSen']),
      floatSen: readInt(d['floatSen']),
      countedSen: readInt(d['countedSen']),
      unitsWithoutCost: readInt(d['unitsWithoutCost']),
      products: products is Map
          ? {
              for (final e in products.entries)
                if (e.value is Map)
                  '${e.key}': ClosingLine.fromMap(e.value as Map),
            }
          : const {},
      closedBy: d['closedBy'] as String? ?? '',
      closedAt: readDate(d['closedAt']),
      sample: d['sample'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'day': Timestamp.fromDate(dateOnly(day)),
    'salesSen': salesSen,
    'cashSen': cashSen,
    'qrSen': qrSen,
    'costSen': costSen,
    'profitSen': profitSen,
    'orderCount': orderCount,
    'wasteSen': wasteSen,
    'saveFoodSen': saveFoodSen,
    'floatSen': floatSen,
    'countedSen': countedSen,
    'unitsWithoutCost': unitsWithoutCost,
    'products': {for (final e in products.entries) e.key: e.value.toMap()},
    'closedBy': closedBy,
    'closedAt': closedAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(closedAt!),
    'sample': sample,
  };
}

/// The kind of campus week [day] is in; unmarked weeks are normal.
String weekTypeOf(DateTime day, Map<String, String> weekTypes) =>
    weekTypes[weekId(day)] ?? WeekType.normal;

/// Average sales and profit per day for one kind of week.
class WeekTypeStats {
  WeekTypeStats(this.type);
  final String type;
  int days = 0;
  int salesSen = 0;
  int profitSen = 0;

  int get salesPerDaySen => days == 0 ? 0 : (salesSen / days).round();
  int get profitPerDaySen => days == 0 ? 0 : (profitSen / days).round();
}

/// "Exam week profit vs a normal week", from the closed days.
class WeekComparison {
  WeekComparison._(this.byType);

  /// Only the kinds of week that have closed days, in WeekType.all order.
  final List<WeekTypeStats> byType;

  WeekTypeStats? get normal =>
      byType.where((s) => s.type == WeekType.normal).firstOrNull;

  /// Profit per day compared with a normal week, e.g. +45 (%). Null when
  /// there is nothing to compare with.
  int? changePct(WeekTypeStats stats) {
    final base = normal?.profitPerDaySen ?? 0;
    if (stats.type == WeekType.normal || base <= 0) return null;
    return ((stats.profitPerDaySen / base - 1) * 100).round();
  }

  factory WeekComparison.of(
    Iterable<DayClosing> closings,
    Map<String, String> weekTypes,
  ) {
    final stats = {for (final t in WeekType.all) t: WeekTypeStats(t)};
    for (final c in closings) {
      final s = stats[weekTypeOf(c.day, weekTypes)]!;
      s.days++;
      s.salesSen += c.salesSen;
      s.profitSen += c.profitSen;
    }
    return WeekComparison._(stats.values.where((s) => s.days > 0).toList());
  }
}
