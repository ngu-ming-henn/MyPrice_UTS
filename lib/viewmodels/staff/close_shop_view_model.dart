import '../../core/utils/format.dart';
import '../../models/money.dart';
import '../../models/order.dart';
import '../../models/stock_movement.dart';
import '../../services/money_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../services/stock_service.dart';
import '../view_model.dart';

/// Close shop: today's sales (live), the cash counted in the drawer note by
/// note, and the difference with the cash the app expects. Saving it makes
/// the day's closing (`closings/{today}`).
class CloseShopViewModel extends ViewModel {
  CloseShopViewModel(
    OrderService orders,
    StockService stock,
    ProductService products,
    this._money,
    this._staffId, {
    DateTime? now,
  }) : today = dateOnly(now ?? DateTime.now()) {
    follow(orders.watchCollectedSince(today), (list) => _orders = list);
    follow(stock.watchMovementsSince(today), (list) => _moves = list);
    follow(products.watchCostPrices(), (map) => _costs = map);
    follow(_money.watchClosing(today), (closing) {
      saved = closing;
      _savedLoaded = true;
    });
    _loadFloat();
  }

  final MoneyService _money;
  final String _staffId;
  final DateTime today;
  List<Order>? _orders;
  List<StockMovement>? _moves;
  Map<String, int>? _costs;
  bool _savedLoaded = false;

  /// Today's closing once saved.
  DayClosing? saved;

  /// Counting again after the shop was already closed today.
  bool recounting = false;

  /// Malaysian notes, largest first (sen).
  static const notes = [10000, 5000, 2000, 1000, 500, 100];

  final _noteCounts = <int, int>{};
  int coinsSen = 0;

  /// Cash put in the drawer at opening (change for customers).
  int floatSen = 0;
  bool _floatChanged = false;

  bool get loading =>
      (_orders == null || _moves == null || _costs == null || !_savedLoaded) &&
      error == null;

  /// Show the saved summary instead of the count.
  bool get showSaved => saved != null && !recounting;

  SalesTotals get totals =>
      SalesTotals.of(_orders ?? const [], _costs ?? const {});

  int get wasteSen => wasteCostSen(_moves ?? const [], _costs ?? const {});

  int noteCount(int note) => _noteCounts[note] ?? 0;

  int get countedSen =>
      notes.fold(0, (sum, n) => sum + n * noteCount(n)) + coinsSen;

  int get expectedSen => floatSen + totals.cashSen;

  /// Below 0: cash is missing from the drawer.
  int get differenceSen => countedSen - expectedSen;

  void setNoteCount(int note, int count) {
    _noteCounts[note] = count < 0 ? 0 : count;
    notify();
  }

  void setCoins(int sen) {
    coinsSen = sen;
    notify();
  }

  void setFloat(int sen) {
    floatSen = sen;
    _floatChanged = true;
    notify();
  }

  void countAgain() {
    recounting = true;
    final s = saved;
    if (s != null && !_floatChanged) floatSen = s.floatSen;
    notify();
  }

  /// The float is usually the same every day: start from the last one.
  Future<void> _loadFloat() async {
    try {
      final last = await _money.lastClosingBefore(today);
      if (last != null && !_floatChanged && !disposed) {
        floatSen = last.floatSen;
        notify();
      }
    } catch (_) {
      // Offline or no history: the owner types it in.
    }
  }

  /// Saves today's closing; returns it with whether it reached the server.
  Future<({DayClosing closing, bool synced})> close() => run(() async {
    final closing = DayClosing.fromTotals(
      day: today,
      totals: totals,
      wasteSen: wasteSen,
      floatSen: floatSen,
      countedSen: countedSen,
      closedBy: _staffId,
    );
    final synced = await _money.saveClosing(closing);
    recounting = false;
    return (closing: closing, synced: synced);
  });
}
