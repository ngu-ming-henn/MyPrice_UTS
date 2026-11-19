import '../../services/money_service.dart';
import '../../services/product_service.dart';
import '../../services/sample_data.dart';
import '../view_model.dart';

/// Staff "More" tab: loading the demo catalogue and sales history.
/// (Profile, language and log out use the app-wide AuthViewModel /
/// SettingsViewModel.)
class MoreViewModel extends ViewModel {
  MoreViewModel(this._products, this._money, this._staffId);

  final ProductService _products;
  final MoneyService _money;
  final String _staffId;

  int get sampleProductCount => buildSampleProducts(DateTime.now()).length;

  /// Adds the sample products that are missing and fills in missing
  /// descriptions and cost prices. Existing stock and prices are kept.
  Future<({int added, int described, int costed})> loadSampleProducts() =>
      run(() => _products.seedSampleProducts(_staffId));

  /// Adds 8 weeks of sample closed days and campus weeks for the Money
  /// screen and the restock plan; returns how many days were added.
  Future<int> loadSampleHistory() => run(
    () =>
        _money.seedSampleHistory(buildSampleProducts(DateTime.now()), _staffId),
  );
}
