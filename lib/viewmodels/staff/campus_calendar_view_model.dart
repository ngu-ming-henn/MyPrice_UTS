import '../../core/constants.dart';
import '../../core/utils/format.dart';
import '../../services/money_service.dart';
import '../view_model.dart';

/// Campus calendar: the owner marks each week as normal, exam, semester
/// break or event (live). The restock plan and the week comparison use it.
class CampusCalendarViewModel extends ViewModel {
  CampusCalendarViewModel(this._money, {DateTime? now})
    : thisWeek = weekStart(now ?? DateTime.now()) {
    follow(_money.watchCalendar(), (map) => _types = map);
  }

  final MoneyService _money;

  /// Monday of the current week.
  final DateTime thisWeek;
  Map<String, String>? _types;

  bool get loading => _types == null && error == null;

  DateTime _week(int offset) =>
      DateTime(thisWeek.year, thisWeek.month, thisWeek.day + 7 * offset);

  /// This week and the next 15 (about one semester).
  List<DateTime> get comingWeeks => [for (var i = 0; i < 16; i++) _week(i)];

  /// The last 12 weeks: marking them lets the app compare past sales.
  List<DateTime> get pastWeeks => [for (var i = 1; i <= 12; i++) _week(-i)];

  String typeOf(DateTime monday) => _types?[dayId(monday)] ?? WeekType.normal;

  /// Returns false if the change is queued offline.
  Future<bool> setType(DateTime monday, String type) =>
      _money.setWeekType(monday, type);
}
