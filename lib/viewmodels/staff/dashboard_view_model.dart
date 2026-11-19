import '../../core/constants.dart';
import '../../core/utils/format.dart';
import '../../models/money.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/restock_plan.dart';
import '../../services/money_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../services/sample_data.dart';
import '../view_model.dart';

/// Staff dashboard (MVVM): follows live Firestore streams (products, the
/// order queue, today's orders, today's closing and the sales history) and
/// turns them into the numbers on the screen. The View redraws by itself
/// whenever any of them changes.
class DashboardViewModel extends ViewModel {
  DashboardViewModel(
    this._products,
    OrderService orders,
    MoneyService money,
    this._staffId, {
    DateTime? now,
  }) : _now = now {
    final today = dateOnly(now ?? DateTime.now());
    follow(_products.watchAllProducts(), (list) => _all = list);
    follow(orders.watchQueue(), (list) => _queue = list);
    follow(orders.watchOrdersSince(today), (list) => _today = list);
    follow(money.watchClosing(today), (closing) {
      closedToday = closing;
      closingLoaded = true;
    });
    follow(
      money.watchClosingsSince(
        DateTime(today.year, today.month, today.day - AppRules.historyDays),
      ),
      (list) => _history = list,
    );
    follow(money.watchCalendar(), (map) => _weekTypes = map);
  }

  final ProductService _products;
  final String _staffId;
  final DateTime? _now;
  List<Product>? _all;
  List<Order> _queue = const [];
  List<Order>? _today;
  List<DayClosing> _history = const [];
  Map<String, String> _weekTypes = const {};

  /// Today's closing, once the shop has been closed.
  DayClosing? closedToday;
  bool closingLoaded = false;

  DateTime get _clock => _now ?? DateTime.now();

  /// Closing time has passed and the shop is not closed yet.
  bool get closeShopDue =>
      closingLoaded &&
      closedToday == null &&
      _clock.hour >= AppRules.closingHour;

  /// What to order (Dashboard card).
  RestockPlan get restockPlan => RestockPlan.build(
    products: _all ?? const [],
    closings: _history,
    weekTypes: _weekTypes,
    queue: _queue,
    today: dateOnly(_clock),
  );

  /// No products at all yet: offer the sample catalogue.
  bool get shopIsEmpty => _all != null && _all!.isEmpty;

  Iterable<Product> get _active =>
      (_all ?? const <Product>[]).where((p) => p.isActive);

  int get lowStockCount => _active.where((p) => p.needsRestock).length;

  int get nearExpiryCount => _active.where((p) => p.needsExpiryAction()).length;

  int get pendingCount => _queue.where((o) => o.isPending).length;

  int get readyCount => _queue.where((o) => o.isReady).length;

  bool get loadingSales => _today == null && error == null;

  /// Sales = collected orders (money taken), same rule as Reports; newest
  /// first.
  List<Order> get todaySales =>
      (_today ?? const <Order>[]).where((o) => o.isCollected).toList()
        ..sort((a, b) => b.sortTime.compareTo(a.sortTime));

  int get salesTodaySen => todaySales.fold(0, (sum, o) => sum + o.totalSen);

  int get sampleProductCount => buildSampleProducts(DateTime.now()).length;

  /// Loads the demo catalogue; returns how many products were added.
  Future<int> loadSampleProducts() =>
      run(() async => (await _products.seedSampleProducts(_staffId)).added);
}
