import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/utils/codes.dart';
import '../core/utils/errors.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import 'sample_data.dart';

class ProductService {
  ProductService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  /// Cost prices live in their own collection that only staff can read, so
  /// students never see the koperasi's margins.
  CollectionReference<Map<String, dynamic>> get _costs =>
      _db.collection('product_costs');

  List<Product> _toSortedList(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map(Product.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Catalogue for students (disabled products are hidden).
  Stream<List<Product>> watchActiveProducts() => _products
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map(_toSortedList);

  /// One-off load of the catalogue (from the phone cache when offline).
  Future<List<Product>> getActiveProducts() async =>
      _toSortedList(await _products.where('isActive', isEqualTo: true).get());

  /// Everything, for staff screens and alerts.
  Stream<List<Product>> watchAllProducts() =>
      _products.snapshots().map(_toSortedList);

  Stream<Product?> watchProduct(String barcode) {
    if (!isValidProductCode(barcode)) return Stream.value(null);
    return _products
        .doc(barcode)
        .snapshots()
        .map((doc) => doc.exists ? Product.fromDoc(doc) : null);
  }

  Future<Product?> findByBarcode(String code) async {
    if (!isValidProductCode(code)) return null;
    final doc = await _products.doc(code).get();
    return doc.exists ? Product.fromDoc(doc) : null;
  }

  // ------------------------------------------------------------ cost prices

  /// Cost price (sen) of every product that has one, by barcode. Staff only.
  Stream<Map<String, int>> watchCostPrices() => _costs.snapshots().map(
    (s) => {
      for (final d in s.docs)
        if (d.data()['costPriceSen'] is num)
          d.id: (d.data()['costPriceSen'] as num).toInt(),
    },
  );

  Future<int?> getCostPrice(String barcode) async {
    if (!isValidProductCode(barcode)) return null;
    final v = (await _costs.doc(barcode).get()).data()?['costPriceSen'];
    return v is num ? v.toInt() : null;
  }

  void _writeCost(WriteBatch batch, String barcode, int? costPriceSen) {
    final ref = _costs.doc(barcode);
    if (costPriceSen == null) {
      batch.delete(ref);
    } else {
      batch.set(ref, {
        'costPriceSen': costPriceSen,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // --------------------------------------------------------------- products

  /// Creates a product. Opening stock (if any) is logged as a stock-in
  /// movement in the same batch.
  Future<void> createProduct(
    Product product, {
    required String staffId,
    String source = MovementSource.manual,
    int? costPriceSen,
  }) async {
    if (!isValidProductCode(product.barcode)) {
      throw const AppException(
        'That barcode cannot be used as a product code.',
      );
    }
    final ref = _products.doc(product.barcode);
    if ((await ref.get()).exists) {
      throw AppException('A product with code {code} already exists.', {
        'code': product.barcode,
      });
    }
    final batch = _db.batch()..set(ref, product.toNewMap());
    if (costPriceSen != null) _writeCost(batch, product.barcode, costPriceSen);
    if (product.stock > 0) {
      batch.set(
        _db.collection('stock_movements').doc(),
        StockMovement.newMap(
          productId: product.barcode,
          productName: product.name,
          type: MovementType.stockIn,
          quantity: product.stock,
          source: source,
          byUserId: staffId,
          expiryDate: product.expiryDate,
          stockAfter: product.stock,
        ),
      );
    }
    await batch.commit();
  }

  /// Updates details and the cost price (null removes it); stock is
  /// changed through StockService.
  Future<void> updateProduct(Product product, {int? costPriceSen}) {
    final batch = _db.batch()
      ..update(_products.doc(product.barcode), product.toDetailsMap());
    _writeCost(batch, product.barcode, costPriceSen);
    return batch.commit();
  }

  Future<void> setActive(String barcode, bool active) => _products
      .doc(barcode)
      .update({'isActive': active, 'updatedAt': FieldValue.serverTimestamp()});

  /// Sets (or clears with null) the Save Food price.
  Future<void> setSaveFoodPrice(String barcode, int? priceSen) =>
      _products.doc(barcode).update({
        'saveFoodPriceSen': priceSen,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// A free "SK-000123" code for items without a barcode.
  Future<String> newShortCode() async {
    for (var i = 0; i < 10; i++) {
      final code = generateShortProductCode();
      if (!(await _products.doc(code).get()).exists) return code;
    }
    throw const AppException('Could not generate a free code, try again.');
  }

  /// Adds the demo catalogue (section 14: "create ~50 sample products").
  /// Existing products keep their stock and prices; sample products loaded
  /// before descriptions or cost prices existed get them. Returns how many
  /// products were added, got a description and got a cost price.
  Future<({int added, int described, int costed})> seedSampleProducts(
    String staffId,
  ) async {
    final existing = {
      for (final d in (await _products.get()).docs) d.id: d.data(),
    };
    final costed = {for (final d in (await _costs.get()).docs) d.id};
    final batch = _db.batch();
    var added = 0;
    var described = 0;
    var newCosts = 0;
    for (final p in buildSampleProducts(DateTime.now())) {
      final old = existing[p.barcode];
      if (!costed.contains(p.barcode) &&
          (old == null || old['priceSen'] == p.priceSen)) {
        _writeCost(batch, p.barcode, sampleCostSen(p));
        if (old != null) newCosts++;
      }
      if (old != null) {
        // Only fill it in if staff have not renamed or described it.
        final hasText = ((old['description'] as String?) ?? '').trim() != '';
        if (!hasText && old['name'] == p.name && p.description != null) {
          batch.update(_products.doc(p.barcode), {
            'description': p.description,
          });
          described++;
        }
        continue;
      }
      batch.set(_products.doc(p.barcode), p.toNewMap());
      batch.set(
        _db.collection('stock_movements').doc(),
        StockMovement.newMap(
          productId: p.barcode,
          productName: p.name,
          type: MovementType.stockIn,
          quantity: p.stock,
          source: MovementSource.manual,
          byUserId: staffId,
          expiryDate: p.expiryDate,
          stockAfter: p.stock,
        ),
      );
      added++;
    }
    if (added + described + newCosts > 0) await batch.commit();
    return (added: added, described: described, costed: newCosts);
  }
}
