import 'dart:async';

import '../../core/constants.dart';
import '../../core/utils/format.dart';
import '../../models/money.dart';
import '../../models/order.dart';
import '../../models/stock_movement.dart';
import '../../services/money_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../services/stock_service.dart';
import '../view_model.dart';

/// Money tab: sales, cost and profit for today / 7 / 30 days (live), the
/// products that earn the most and the least, waste vs Save Food, the
/// closing history and how each kind of campus week compares.
class MoneyViewModel extends ViewModel {
  MoneyViewModel(
    this._orders,
    this._stock,
    ProductService products,
    MoneyService money, {
    DateTime? now,
  }) : _today = dateOnly(now ?? DateTime.now()) {
    follow(products.watchCostPrices(), (map) {
      _costs = map;
      _rebuild();
    });
    follow(
      money.watchClosingsSince(
        DateTime(_today.year, _today.month, _today.day - AppRules.historyDays),
      ),
      (list) {
        _closings = list;
        _rebuild();
      },
    );
    follow(money.watchCalendar(), (map) => _weekTypes = map);
    _subscribe();
  }

  final OrderService _orders;
  final StockService _stock;
  final DateTime _today;
  StreamSubscription<List<Order>>? _orderSub;
  StreamSubscription<List<StockMovement>>? _moveSub;
  List<Order>? _orderList;
  List<StockMovement>? _moves;
  Map<String, int>? _costs;
  List<DayClosing>? _closings;
  Map<String, String> _weekTypes = const {};

  /// 1 = today, 7 or 30 days.
  int days = 1;
  late DateTime since;

  /// The last finished report; kept (dimmed) while a new period loads.
  MoneyReport? report;
  bool refreshing = false;

  bool get loading => report == null && error == null;

  void showDays(int value) {
    if (value == days) return;
    days = value;
    refreshing = true;
    _subscribe();
    notify();
  }

  /// Closed days in the chosen period, newest first.
  List<DayClosing> get closings => (_closings ?? const <DayClosing>[])
      .where((c) => !c.day.isBefore(since))
      .toList();

  /// Days in the period when cash was missing from the drawer.
  int get shortDays => closings.where((c) => c.cashShort).length;

  /// Profit per day by kind of campus week (last [AppRules.historyDays]).
  WeekComparison get weeks =>
      WeekComparison.of(_closings ?? const [], _weekTypes);

  void _subscribe() {
    _orderSub?.cancel();
    _moveSub?.cancel();
    _orderList = null;
    _moves = null;
    since = DateTime(_today.year, _today.month, _today.day - (days - 1));
    _orderSub = _orders.watchCollectedSince(since).listen((list) {
      _orderList = list;
      _rebuild();
    }, onError: _failed);
    _moveSub = _stock.watchMovementsSince(since).listen((list) {
      _moves = list;
      _rebuild();
    }, onError: _failed);
  }

  void _rebuild() {
    if (_orderList == null ||
        _moves == null ||
        _costs == null ||
        _closings == null) {
      return;
    }
    report = MoneyReport.build(
      orders: _orderList!,
      movements: _moves!,
      closings: _closings!,
      costs: _costs!,
      since: since,
      days: days,
      today: _today,
    );
    refreshing = false;
    error = null;
    notify();
  }

  void _failed(Object e) {
    error = e;
    notify();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _moveSub?.cancel();
    super.dispose();
  }
}

/// All money numbers for one period, computed once per snapshot. Days
/// already closed use their saved summary (like a shop's end-of-day
/// report); today and days that were not closed are added up from the
/// orders and stock movements.
class MoneyReport {
  MoneyReport({
    required this.totals,
    required this.wasteSen,
    required this.dailyProfit,
  });

  final SalesTotals totals;

  /// Cost of the stock written off as expired or damaged.
  final int wasteSen;

  /// Profit per day (sen) and orders, oldest first.
  final List<({DateTime day, int sen, int orders})> dailyProfit;

  List<ProductSales> get _withProfit =>
      totals.byProduct.values.where((p) => p.profitSen != null).toList();

  /// The 5 products that earned the most.
  List<ProductSales> get best =>
      (_withProfit..sort((a, b) => b.profitSen!.compareTo(a.profitSen!)))
          .take(5)
          .toList();

  /// The 5 that earned the least (not shown with the best ones again).
  List<ProductSales> get worst {
    final all = _withProfit
      ..sort((a, b) => a.profitSen!.compareTo(b.profitSen!));
    final top = best.map((p) => p.productId).toSet();
    return all.where((p) => !top.contains(p.productId)).take(5).toList();
  }

  factory MoneyReport.build({
    required List<Order> orders,
    required List<StockMovement> movements,
    required List<DayClosing> closings,
    required Map<String, int> costs,
    required DateTime since,
    required int days,
    required DateTime today,
  }) {
    int dayIndex(DateTime d) => daysUntil(d, from: since);
    bool inPeriod(int i) => i >= 0 && i < days;

    // Closed days before today, by day in the period.
    final closed = <int, DayClosing>{
      for (final c in closings)
        if (inPeriod(dayIndex(c.day)) && dateOnly(c.day).isBefore(today))
          dayIndex(c.day): c,
    };
    final open = List.generate(days, (_) => <Order>[]);
    for (final o in orders.where((o) => o.isCollected)) {
      final i = dayIndex(o.paidTime);
      if (inPeriod(i) && !closed.containsKey(i)) open[i].add(o);
    }
    final openMoves = movements.where(
      (m) => !closed.containsKey(dayIndex(m.createdAt ?? today)),
    );

    return MoneyReport(
      totals: SalesTotals.combined(
        orders: open.expand((day) => day),
        costs: costs,
        closings: closed.values,
      ),
      wasteSen:
          wasteCostSen(openMoves, costs) +
          closed.values.fold(0, (total, c) => total + c.wasteSen),
      dailyProfit: [
        for (var i = 0; i < days; i++)
          (
            day: DateTime(since.year, since.month, since.day + i),
            sen:
                closed[i]?.profitSen ??
                SalesTotals.of(open[i], costs).profitSen,
            orders: closed[i]?.orderCount ?? open[i].length,
          ),
      ],
    );
  }
}
