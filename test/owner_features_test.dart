import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/constants.dart';
import 'package:smartshop/core/utils/format.dart';
import 'package:smartshop/models/money.dart';
import 'package:smartshop/models/order.dart';
import 'package:smartshop/models/product.dart';
import 'package:smartshop/models/restock_plan.dart';
import 'package:smartshop/models/stock_movement.dart';
import 'package:smartshop/services/money_service.dart';
import 'package:smartshop/services/order_service.dart';
import 'package:smartshop/services/product_service.dart';
import 'package:smartshop/services/sample_data.dart';
import 'package:smartshop/services/stock_service.dart';
import 'package:smartshop/viewmodels/staff/close_shop_view_model.dart';
import 'package:smartshop/viewmodels/staff/money_view_model.dart';
import 'package:smartshop/viewmodels/staff/restock_view_model.dart';

// Owner features: profit, Close shop (cash check), the week comparison and
// the restock plan. Thursday 19 Nov 2026 is "today" in these tests.

final today = DateTime(2026, 11, 19);

OrderItem item(String id, int priceSen, int qty, {bool saveFood = false}) =>
    OrderItem(
      productId: id,
      name: id,
      unitPriceSen: priceSen,
      qty: qty,
      isSaveFood: saveFood,
    );

Order paid(
  String id,
  List<OrderItem> items, {
  String status = OrderStatus.collected,
  String? method = PaymentMethod.cash,
  DateTime? at,
}) => Order(
  id: id,
  type: OrderType.counter,
  userId: null,
  customerName: null,
  items: items,
  totalSen: totalOf(items),
  status: status,
  noPlasticBag: false,
  pickupCode: null,
  pointsEarned: 0,
  paymentMethod: method,
  createdAt: at ?? today.add(const Duration(hours: 10)),
  collectedAt: at ?? today.add(const Duration(hours: 10)),
);

StockMovement move(String productId, String type, int qty) => StockMovement(
  id: '$productId-$type',
  productId: productId,
  productName: productId,
  type: type,
  quantity: qty,
  source: MovementSource.manual,
  byUserId: 'staff-1',
);

Product product(
  String id, {
  int stock = 10,
  int threshold = 5,
  bool active = true,
}) => Product(
  barcode: id,
  name: id,
  category: 'Drinks',
  priceSen: 300,
  stock: stock,
  lowStockThreshold: threshold,
  isActive: active,
);

DayClosing closed(
  DateTime day, {
  int profitSen = 1000,
  int salesSen = 3000,
  Map<String, int> units = const {},
}) => DayClosing(
  day: day,
  salesSen: salesSen,
  cashSen: salesSen,
  qrSen: 0,
  costSen: salesSen - profitSen,
  profitSen: profitSen,
  orderCount: 10,
  wasteSen: 0,
  saveFoodSen: 0,
  floatSen: 0,
  countedSen: salesSen,
  products: {
    for (final e in units.entries)
      e.key: ClosingLine(name: e.key, units: e.value, salesSen: e.value * 300),
  },
);

void main() {
  test('weeks start on Monday and have a stable ID', () {
    expect(today.weekday, DateTime.thursday);
    expect(weekStart(today), DateTime(2026, 11, 16));
    expect(weekId(today), '2026-11-16');
    expect(weekId(DateTime(2026, 11, 22)), '2026-11-16'); // Sunday
    expect(dayId(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('profit counts only products with a cost price', () {
    final t = SalesTotals.of(
      [
        paid('o1', [item('A', 300, 2), item('B', 500, 1)]),
        paid('o2', [
          item('C', 100, 3, saveFood: true),
        ], method: PaymentMethod.qr),
        paid('o3', [item('A', 300, 9)], status: OrderStatus.cancelled),
      ],
      {'A': 200, 'C': 80},
    );
    expect(t.salesSen, 1400);
    expect(t.cashSen, 1100);
    expect(t.qrSen, 300);
    expect(t.orderCount, 2); // the cancelled order is not a sale
    expect(t.costSen, 640); // 2 × 2.00 + 3 × 0.80
    expect(t.profitSen, 260); // (6.00 + 3.00) - 6.40
    expect(t.marginPct, 29);
    expect(t.unitsWithoutCost, 1); // B has no cost price
    expect(t.saveFoodSen, 300);
    expect(t.byProduct['A']!.profitSen, 200);
    expect(t.byProduct['B']!.profitSen, isNull);
    expect(t.byProduct.map((id, p) => MapEntry(id, p.units)), {
      'A': 2,
      'B': 1,
      'C': 3,
    });
  });

  test('waste is the cost of expired and damaged stock', () {
    final moves = [
      move('A', MovementType.expired, -3),
      move('B', MovementType.damaged, -1), // no cost price: not counted
      move('A', MovementType.sale, -2), // a sale is not waste
    ];
    expect(wasteCostSen(moves, {'A': 200}), 600);
  });

  test('the cash check compares the drawer with float + cash sales', () {
    final c = DayClosing(
      day: today,
      salesSen: 1400,
      cashSen: 1100,
      qrSen: 300,
      costSen: 640,
      profitSen: 260,
      orderCount: 2,
      wasteSen: 0,
      saveFoodSen: 0,
      floatSen: 5000,
      countedSen: 5860,
    );
    expect(c.id, '2026-11-19');
    expect(c.expectedCashSen, 6100);
    expect(c.differenceSen, -240);
    expect(c.cashShort, isTrue);
    expect(c.cashMatches, isFalse);
  });

  test('exam weeks are compared with normal weeks', () {
    final examDay = DateTime(2026, 10, 27);
    final weeks = WeekComparison.of(
      [
        closed(DateTime(2026, 11, 10), profitSen: 1000),
        closed(DateTime(2026, 11, 11), profitSen: 1200),
        closed(examDay, profitSen: 1650),
      ],
      {weekId(examDay): WeekType.exam},
    );
    expect(weeks.byType.map((s) => s.type), [WeekType.normal, WeekType.exam]);
    expect(weeks.normal!.profitPerDaySen, 1100);
    final exam = weeks.byType.last;
    expect(exam.days, 1);
    expect(weeks.changePct(exam), 50);
    expect(weeks.changePct(weeks.normal!), isNull);
  });

  group('restock plan', () {
    // History: Milo sells 2 a day in normal weeks, 4 a day in exam weeks.
    final examWeekDay1 = DateTime(2026, 10, 27);
    final examWeekDay2 = DateTime(2026, 10, 28);
    final history = [
      for (final d in [9, 10, 11, 12])
        closed(DateTime(2026, 11, d), units: {'Milo': 2}),
      closed(examWeekDay1, units: {'Milo': 4}),
      closed(examWeekDay2, units: {'Milo': 4}),
      // Today is not finished: not part of the history.
      closed(today, units: {'Milo': 50}),
    ];
    final calendar = {
      weekId(examWeekDay1): WeekType.exam,
      '2026-11-23': WeekType.exam, // next week
    };
    final pendingMilo = Order(
      id: 'p1',
      type: OrderType.preorder,
      userId: 'student-1',
      customerName: 'Test1',
      items: [item('Milo', 300, 3)],
      totalSen: 900,
      status: OrderStatus.pending,
      noPlasticBag: true,
      pickupCode: 'ABC234',
      pointsEarned: 5,
    );

    RestockPlan build() => RestockPlan.build(
      products: [
        product('Milo', stock: 10),
        product('Pen', stock: 50), // not selling, plenty left
        product('Bread', stock: 2), // no history, but low stock
        product('Old', stock: 0, active: false),
      ],
      closings: history,
      weekTypes: calendar,
      queue: [pendingMilo],
      today: today,
    );

    test('orders for the exam week coming up', () {
      final plan = build();
      expect(plan.historyDays, 6);
      expect(plan.specialType, WeekType.exam);
      expect(plan.specialFrom, DateTime(2026, 11, 23));
      expect(plan.lines.map((l) => l.product.name), ['Milo', 'Bread']);

      final milo = plan.lines.first;
      // Open days: Fri (normal) + Mon-Thu (exam) = 2 + 4 × 4 = 18 units.
      expect(milo.perDay, closeTo(3.6, 0.001));
      // 3 are promised to a pre-order that is not packed yet.
      expect(milo.available, 7);
      // 18 for the week + 5 (low-stock level) - 7 in stock.
      expect(milo.suggestQty, 16);
      expect(milo.daysLeft, closeTo(1.94, 0.01));
      expect(milo.specialChangePct, 100);
    });

    test('low-stock items without history are topped up', () {
      final bread = build().lines.last;
      expect(bread.daysLeft, isNull);
      expect(bread.suggestQty, 3); // up to the low-stock level of 5
    });
  });

  test('sample history: 8 weeks, an exam week next week, exam sells more', () {
    final products = buildSampleProducts(today);
    final sample = buildSampleHistory(today, products, 'staff-1');
    expect(sample.closings, hasLength(40)); // 8 weeks × Mon-Fri
    expect(sample.closings.every((c) => c.day.isBefore(today)), isTrue);
    expect(sample.closings.every((c) => c.sample), isTrue);
    expect(sample.closings.where((c) => c.cashShort), hasLength(2));
    expect(sample.weekTypes[weekId(DateTime(2026, 11, 23))], WeekType.exam);

    final weeks = WeekComparison.of(sample.closings, sample.weekTypes);
    final exam = weeks.byType.firstWhere((s) => s.type == WeekType.exam);
    final pause = weeks.byType.firstWhere(
      (s) => s.type == WeekType.semesterBreak,
    );
    expect(weeks.changePct(exam)!, greaterThan(20));
    expect(weeks.changePct(pause)!, lessThan(-50));

    final plan = RestockPlan.build(
      products: products,
      closings: sample.closings,
      weekTypes: sample.weekTypes,
      queue: const [],
      today: today,
    );
    expect(plan.specialType, WeekType.exam);
    expect(plan.lines, isNotEmpty);
    // Same numbers every time (fixed seed), so the demo is repeatable.
    expect(
      buildSampleHistory(today, products, 'staff-1').closings.first.salesSen,
      sample.closings.first.salesSen,
    );
  });

  test('daily profit is grouped by the day the money was taken', () {
    final report = MoneyReport.build(
      orders: [
        paid('a', [item('A', 300, 1)], at: DateTime(2026, 11, 17, 9)),
        paid('b', [item('A', 300, 2)], at: DateTime(2026, 11, 19, 9)),
      ],
      movements: const [],
      closings: const [],
      costs: {'A': 200},
      since: DateTime(2026, 11, 13),
      days: 7,
      today: today,
    );
    expect(report.dailyProfit.map((d) => d.sen), [0, 0, 0, 0, 100, 0, 200]);
    expect(report.totals.profitSen, 300);
    expect(report.best.single.productId, 'A');
    expect(report.worst, isEmpty); // A is already in "earns the most"
  });

  test('closed days count with their saved summary, today from orders', () {
    final tuesday = DateTime(2026, 11, 17);
    final report = MoneyReport.build(
      orders: [
        // Already in Tuesday's closing: not counted twice.
        paid('a', [
          item('A', 300, 1),
        ], at: tuesday.add(const Duration(hours: 9))),
        paid('b', [item('A', 300, 2)], at: today.add(const Duration(hours: 9))),
      ],
      movements: [move('A', MovementType.expired, -1)], // no date: today
      closings: [
        DayClosing.fromTotals(
          day: tuesday,
          totals: SalesTotals.of(
            [
              paid('a', [item('A', 300, 1)]),
              paid('c', [item('B', 500, 1)], method: PaymentMethod.qr),
            ],
            {'A': 200},
          ),
          wasteSen: 150,
          floatSen: 5000,
          countedSen: 5300,
          closedBy: 'staff-1',
        ),
        // Today's closing is ignored: today is always counted live.
        closed(today, profitSen: 99999, salesSen: 99999),
      ],
      costs: {'A': 200},
      since: DateTime(2026, 11, 13),
      days: 7,
      today: today,
    );
    final t = report.totals;
    expect(t.orderCount, 3);
    expect(t.salesSen, 300 + 500 + 600);
    expect(t.qrSen, 500);
    expect(t.profitSen, 100 + 200); // B has no cost price
    expect(t.unitsWithoutCost, 1);
    expect(t.byProduct['A']!.units, 3);
    expect(report.wasteSen, 150 + 200);
    expect(report.dailyProfit[4].sen, 100); // Tuesday, from the closing
    expect(report.dailyProfit[6].sen, 200); // today, from the orders
  });

  group('ViewModels', () {
    test('close shop: counts the drawer and saves the day', () async {
      final orders = _Orders();
      final money = _Money();
      final vm = CloseShopViewModel(
        orders,
        _Stock(),
        _Products(),
        money,
        'staff-1',
        now: today.add(const Duration(hours: 18)),
      );
      orders.collected.add([
        paid('o1', [item('A', 300, 2)]),
        paid('o2', [item('A', 300, 1)], method: PaymentMethod.qr),
      ]);
      money.closing.add(null);
      await _settle();

      expect(vm.loading, isFalse);
      expect(vm.showSaved, isFalse);
      expect(vm.totals.cashSen, 600);
      expect(vm.floatSen, 5000); // from the last closing
      expect(vm.expectedSen, 5600);

      vm.setNoteCount(5000, 1); // RM 50
      vm.setNoteCount(500, 1); // RM 5
      vm.setCoins(80);
      expect(vm.countedSen, 5580);
      expect(vm.differenceSen, -20);

      final result = await vm.close();
      expect(result.synced, isTrue);
      final saved = money.saved.single;
      expect(saved.id, '2026-11-19');
      expect(saved.salesSen, 900);
      expect(saved.qrSen, 300);
      expect(saved.profitSen, 300); // 3 × (3.00 - 2.00)
      expect(saved.countedSen, 5580);
      expect(saved.cashShort, isTrue);
      expect(saved.unitsByProduct, {'A': 3});
      vm.dispose();
    });

    test('restock: the owner can change amounts before sending', () async {
      final money = _Money();
      final vm = RestockViewModel(_Products(), _Orders(), money, now: today);
      money.history.add([
        for (final d in [16, 17, 18])
          closed(DateTime(2026, 11, d), units: {'A': 3}),
      ]);
      money.calendar.add(const {});
      await _settle();

      final line = vm.plan.lines.single;
      expect(line.product.name, 'A');
      expect(vm.qtyFor(line), line.suggestQty);
      expect(vm.orderMessage(), contains('• A × ${line.suggestQty}'));

      vm.setQty('A', 0);
      expect(vm.orderCount, 0);
      expect(vm.orderMessage(), isNot(contains('• A')));
      vm.dispose();
    });
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

class _Orders implements OrderService {
  final collected = StreamController<List<Order>>.broadcast();

  @override
  Stream<List<Order>> watchCollectedSince(DateTime since) => collected.stream;
  @override
  Stream<List<Order>> watchQueue() => Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stock implements StockService {
  @override
  Stream<List<StockMovement>> watchMovementsSince(DateTime since) =>
      Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Products implements ProductService {
  @override
  Stream<Map<String, int>> watchCostPrices() => Stream.value({'A': 200});
  @override
  Stream<List<Product>> watchAllProducts() => Stream.value([product('A')]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Money implements MoneyService {
  final closing = StreamController<DayClosing?>.broadcast();
  final history = StreamController<List<DayClosing>>.broadcast();
  final calendar = StreamController<Map<String, String>>.broadcast();
  final saved = <DayClosing>[];

  @override
  Stream<DayClosing?> watchClosing(DateTime day) => closing.stream;
  @override
  Stream<List<DayClosing>> watchClosingsSince(DateTime since) => history.stream;
  @override
  Stream<Map<String, String>> watchCalendar() => calendar.stream;
  @override
  Future<DayClosing?> lastClosingBefore(DateTime day) async =>
      closed(DateTime(2026, 11, 18)).copyFloat(5000);
  @override
  Future<bool> saveClosing(DayClosing closing) async {
    saved.add(closing);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

extension on DayClosing {
  DayClosing copyFloat(int floatSen) => DayClosing(
    day: day,
    salesSen: salesSen,
    cashSen: cashSen,
    qrSen: qrSen,
    costSen: costSen,
    profitSen: profitSen,
    orderCount: orderCount,
    wasteSen: wasteSen,
    saveFoodSen: saveFoodSen,
    floatSen: floatSen,
    countedSen: countedSen,
  );
}
