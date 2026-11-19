import '../../core/constants.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/money.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/restock_plan.dart';
import '../../services/money_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../view_model.dart';

/// Restock plan: what to order before the supplier comes again, from the
/// closed days, the Campus calendar and the pre-orders waiting to be packed
/// (all live). The owner can change each amount before sending the list.
class RestockViewModel extends ViewModel {
  RestockViewModel(
    ProductService products,
    OrderService orders,
    MoneyService money, {
    DateTime? now,
  }) : today = dateOnly(now ?? DateTime.now()) {
    follow(products.watchAllProducts(), (list) {
      _products = list;
      _plan = null;
    });
    follow(orders.watchQueue(), (list) {
      _queue = list;
      _plan = null;
    });
    follow(
      money.watchClosingsSince(
        DateTime(today.year, today.month, today.day - AppRules.historyDays),
      ),
      (list) {
        _closings = list;
        _plan = null;
      },
    );
    follow(money.watchCalendar(), (map) {
      _weekTypes = map;
      _plan = null;
    });
  }

  final DateTime today;
  List<Product>? _products;
  List<Order> _queue = const [];
  List<DayClosing>? _closings;
  Map<String, String> _weekTypes = const {};
  final _qty = <String, int>{};
  RestockPlan? _plan;

  bool get loading => (_products == null || _closings == null) && error == null;

  /// Worked out again only when the data changes.
  RestockPlan get plan => _plan ??= RestockPlan.build(
    products: _products ?? const [],
    closings: _closings ?? const [],
    weekTypes: _weekTypes,
    queue: _queue,
    today: today,
  );

  /// The amount to order: the owner's change, or the suggestion.
  int qtyFor(RestockLine line) => _qty[line.product.barcode] ?? line.suggestQty;

  void setQty(String barcode, int qty) {
    _qty[barcode] = qty < 0 ? 0 : qty;
    notify();
  }

  /// Number of products with something to order.
  int get orderCount => plan.lines.where((l) => qtyFor(l) > 0).length;

  /// The order as a WhatsApp message for the supplier.
  String orderMessage() {
    final lines = [
      for (final l in plan.lines)
        if (qtyFor(l) > 0) '• ${l.product.name} × ${qtyFor(l)}',
    ];
    return [
      AppStrings.tr('Hi, an order from {shop} ({date}):', {
        'shop': ShopLocation.name,
        'date': formatDate(today),
      }),
      ...lines,
      AppStrings.tr('Thank you!'),
    ].join('\n');
  }
}
