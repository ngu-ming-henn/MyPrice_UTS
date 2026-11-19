import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/staff/campus_calendar_view_model.dart';
import '../../widgets/common.dart';

/// Campus calendar: mark each week as normal, exam, semester break or
/// event. The restock plan orders for the kind of week coming up, and the
/// Money tab compares them ([CampusCalendarViewModel]).
class CampusCalendarScreen extends StatelessWidget {
  const CampusCalendarScreen({super.key});

  Future<void> _set(BuildContext context, DateTime monday, String type) async {
    try {
      await context.read<CampusCalendarViewModel>().setType(monday, type);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CampusCalendarViewModel>();
    final theme = Theme.of(context);
    Widget week(DateTime monday) => _WeekTile(
      monday: monday,
      type: vm.typeOf(monday),
      isThisWeek: monday == vm.thisWeek,
      onChanged: (type) => _set(context, monday, type),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Campus calendar'))),
      body: vm.error != null
          ? ErrorView(error: vm.error!)
          : vm.loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.tr(
                    'Sales change a lot during exams and semester breaks. '
                    'Mark the weeks once a semester: the restock plan orders '
                    'for the week coming up, and Money compares them.',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                SectionHeader(title: context.tr('Coming weeks')),
                Card(
                  child: Column(
                    children: [for (final w in vm.comingWeeks) week(w)],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const Icon(Icons.history),
                      title: Text(context.tr('Past weeks')),
                      subtitle: Text(
                        context.tr('Mark them so past sales can be compared'),
                      ),
                      children: [for (final w in vm.pastWeeks) week(w)],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({
    required this.monday,
    required this.type,
    required this.isThisWeek,
    required this.onChanged,
  });

  final DateTime monday;
  final String type;
  final bool isThisWeek;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final color = switch (type) {
      WeekType.exam => const Color(0xFF8E24AA),
      WeekType.semesterBreak => const Color(0xFF00838F),
      WeekType.event => AppColors.warning,
      _ => Colors.blueGrey,
    };
    return ListTile(
      selected: isThisWeek,
      title: Text(
        '${dateFormat('d MMM').format(monday)} – '
        '${dateFormat('d MMM').format(sunday)}',
      ),
      subtitle: isThisWeek ? Text(context.tr('This week')) : null,
      trailing: PopupMenuButton<String>(
        tooltip: context.tr('Kind of week'),
        initialValue: type,
        onSelected: onChanged,
        itemBuilder: (_) => [
          for (final t in WeekType.all)
            PopupMenuItem(value: t, child: Text(context.tr(WeekType.label(t)))),
        ],
        child: Pill(
          label: context.tr(WeekType.label(type)),
          color: color,
          icon: Icons.arrow_drop_down,
        ),
      ),
    );
  }
}
