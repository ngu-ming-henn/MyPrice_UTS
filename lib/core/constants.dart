/// Business rules from the design document (section 7.4).
/// Agree the final values with the koperasi before release.
class AppRules {
  AppRules._();

  /// A product is "near expiry" when it expires within this many days.
  static const nearExpiryDays = 3;

  /// Default for new products: low stock when `stock <= lowStockThreshold`.
  static const defaultLowStockThreshold = 5;

  /// Green points for an order collected without a plastic bag.
  static const pointsNoPlasticBag = 5;

  /// Green points for every Save Food unit bought.
  static const pointsPerSaveFoodItem = 10;

  /// Redemption: this many points = RM1 voucher.
  static const pointsPerRinggitVoucher = 100;

  /// Estimated shopping time saved by one pre-order (sustainability report).
  static const minutesSavedPerPreorder = 5;

  /// Suggested Save Food discount shown to staff (30% off).
  static const suggestedSaveFoodDiscount = 0.30;

  /// Pickup window: a READY order must be collected the same day before
  /// the koperasi closes at this hour (24h clock).
  static const closingHour = 18;

  /// Opening time shown on the map screen (agree with the koperasi).
  static const openingHour = 8;

  /// Days the koperasi opens (DateTime.monday = 1 ... sunday = 7). The
  /// restock plan only counts sales on these days.
  static const openWeekdays = {1, 2, 3, 4, 5};

  /// The restock plan orders enough stock for this many days (until the
  /// supplier comes again).
  static const restockCoverDays = 7;

  /// Days of closing history used for the restock plan and the week
  /// comparison.
  static const historyDays = 120;
}

/// Where the koperasi is: the "UCTS COOP SHOP" under the stairs at the
/// Academic Resources Centre (position from Google Street View). Google Maps
/// has no pin for it yet, so the app shows its own.
class ShopLocation {
  ShopLocation._();
  static const latitude = 2.341336;
  static const longitude = 111.846039;
  static const name = 'UTS Koperasi (UCTS Coop Shop)';
  static const address =
      'Academic Resources Centre, University of Technology Sarawak, Sibu';

  /// Google Maps directions to the pin (works even without a listing).
  static const directionsUrl =
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

  /// Street View facing the shop entrance.
  static const streetViewUrl =
      'https://www.google.com/maps/@?api=1&map_action=pano'
      '&viewpoint=$latitude,$longitude&heading=290';

  static bool isOpen(DateTime now) =>
      now.hour >= AppRules.openingHour && now.hour < AppRules.closingHour;
}

enum ParkingKind { car, motorcycle }

/// A car or motorcycle park near the koperasi, for the "nearest parking"
/// finder on the map. Shown as "Car park 1", "Motorcycle park 2"...
class ParkingSpot {
  const ParkingSpot(this.kind, this.number, this.latitude, this.longitude);
  final ParkingKind kind;
  final int number;
  final double latitude;
  final double longitude;
}

/// Car parks on campus (within 400 m) and the nearest motorcycle parks,
/// from OpenStreetMap (© OpenStreetMap contributors, November 2026).
const parkingSpots = <ParkingSpot>[
  ParkingSpot(ParkingKind.car, 1, 2.340234, 111.845762),
  ParkingSpot(ParkingKind.car, 2, 2.339774, 111.845600),
  ParkingSpot(ParkingKind.car, 3, 2.340242, 111.844084),
  ParkingSpot(ParkingKind.car, 4, 2.340650, 111.843598),
  ParkingSpot(ParkingKind.car, 5, 2.341223, 111.842857),
  ParkingSpot(ParkingKind.motorcycle, 1, 2.336221, 111.846354),
  ParkingSpot(ParkingKind.motorcycle, 2, 2.336340, 111.844869),
  ParkingSpot(ParkingKind.motorcycle, 3, 2.341330, 111.839615),
];

/// Product categories shown as chips on the student home screen.
/// The AI Budget Planner builds combos from the first three.
const productCategories = <String>[
  'Food',
  'Drinks',
  'Snacks',
  'Stationery',
  'Others',
];

/// Prefix of the member QR code shown on the student profile.
/// Staff scan it at the counter to link a sale to the student.
const memberQrPrefix = 'SKUSER:';

/// Prefix for products without a manufacturer barcode (printed as QR labels).
const shortCodePrefix = 'SK-';

class UserRoles {
  UserRoles._();
  static const student = 'student';
  static const staff = 'staff';
}

class OrderStatus {
  OrderStatus._();
  static const pending = 'pending';
  static const ready = 'ready';
  static const collected = 'collected';
  static const cancelled = 'cancelled';
}

class OrderType {
  OrderType._();
  static const preorder = 'preorder';
  static const counter = 'counter';
}

/// How a sale was paid, chosen by staff when they take the money.
class PaymentMethod {
  PaymentMethod._();
  static const cash = 'cash';

  /// DuitNow QR: the money goes to the koperasi's bank, not the drawer.
  static const qr = 'qr';

  /// English label (translated with tr); null = recorded before the app
  /// asked how.
  static String label(String? method) => switch (method) {
    cash => 'Cash',
    qr => 'DuitNow QR',
    _ => 'Paid at counter',
  };
}

/// What kind of week it is on campus (Campus calendar). Sales change a lot
/// between them, so the restock plan compares weeks of the same kind.
class WeekType {
  WeekType._();
  static const normal = 'normal';
  static const exam = 'exam';
  static const semesterBreak = 'break';
  static const event = 'event';

  static const all = [normal, exam, semesterBreak, event];

  /// English label (translated with tr).
  static String label(String type) => switch (type) {
    exam => 'Exam week',
    semesterBreak => 'Semester break',
    event => 'Event week',
    _ => 'Normal week',
  };
}

class CancelReason {
  CancelReason._();

  /// Staff tapped "Cancel uncollected" after the pickup window.
  static const notCollected = 'not_collected';
}

class MovementType {
  MovementType._();
  static const stockIn = 'stock_in';
  static const sale = 'sale';
  static const order = 'order';
  static const orderCancel = 'order_cancel';
  static const expired = 'expired';
  static const damaged = 'damaged';
  static const adjustment = 'adjustment';
}

class MovementSource {
  MovementSource._();
  static const barcode = 'barcode';
  static const qr = 'qr';
  static const manual = 'manual';
  static const csv = 'csv';
  static const order = 'order';
}
