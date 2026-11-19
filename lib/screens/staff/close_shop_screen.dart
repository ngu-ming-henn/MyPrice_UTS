import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/staff/close_shop_view_model.dart';
import '../../widgets/closing_widgets.dart';
import '../../widgets/common.dart';

/// Close shop: today's sales so far, then count the cash drawer note by
/// note. The app compares it with the cash it expects (float + cash sales)
/// and saves the day's summary ([CloseShopViewModel]).
class CloseShopScreen extends StatefulWidget {
  const CloseShopScreen({super.key});

  @override
  State<CloseShopScreen> createState() => _CloseShopScreenState();
}

class _CloseShopScreenState extends State<CloseShopScreen> {
  final _float = TextEditingController();
  final _coins = TextEditingController();
  final _notes = {
    for (final n in CloseShopViewModel.notes) n: TextEditingController(),
  };
  bool _floatTyped = false;

  late final CloseShopViewModel _vm = context.read<CloseShopViewModel>();

  @override
  void initState() {
    super.initState();
    _vm.addListener(_showFloat);
  }

  /// The float comes from the last closing: show it until it is typed over.
  void _showFloat() {
    if (_floatTyped) return;
    final text = _vm.floatSen == 0 ? '' : senToInput(_vm.floatSen);
    if (_float.text != text) _float.text = text;
  }

  @override
  void dispose() {
    _vm.removeListener(_showFloat);
    _float.dispose();
    _coins.dispose();
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    final vm = _vm;
    final diff = vm.differenceSen;
    if (diff != 0) {
      final ok = await confirm(
        context,
        title: diff < 0
            ? context.tr('Cash is short by {amount}', {
                'amount': formatRM(-diff),
              })
            : context.tr('There is {amount} too much', {
                'amount': formatRM(diff),
              }),
        message: context.tr(
          'Count the drawer again, or close the shop and keep this '
          'difference in the closing history.',
        ),
        confirmLabel: context.tr('Close shop'),
        cancelLabel: context.tr('Count again'),
      );
      if (!ok || !mounted) return;
    }
    try {
      final result = await vm.close();
      if (!mounted) return;
      showSnack(
        context,
        result.synced
            ? context.tr("Shop closed. Today's summary is saved.")
            : context.tr(
                "Shop closed. Today's summary is saved on this phone and "
                'will be sent when you are online.',
              ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CloseShopViewModel>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Close shop'))),
      body: vm.error != null
          ? ErrorView(error: vm.error!)
          : vm.loading
          ? const LoadingView()
          : vm.showSaved
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClosingSummaryCard(closing: vm.saved!),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: vm.countAgain,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.tr('Count again')),
                ),
              ],
            )
          : _countView(context, vm),
    );
  }

  Widget _countView(BuildContext context, CloseShopViewModel vm) {
    final theme = Theme.of(context);
    final t = vm.totals;
    final diff = vm.differenceSen;
    final diffColor = diff < 0
        ? AppColors.error
        : diff > 0
        ? AppColors.warning
        : context.eco;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr('Today so far'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formatDate(vm.today),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      MoneyRow(
                        label: context.tr('Sales ({count} orders)', {
                          'count': t.orderCount,
                        }),
                        value: formatRM(t.salesSen),
                        bold: true,
                      ),
                      MoneyRow(
                        label: context.tr('Cash sales'),
                        value: formatRM(t.cashSen),
                      ),
                      MoneyRow(
                        label: context.tr('DuitNow QR (in the bank)'),
                        value: formatRM(t.qrSen),
                      ),
                      MoneyRow(
                        label: context.tr('Profit'),
                        value: formatRM(t.profitSen),
                        bold: true,
                        color: t.profitSen < 0 ? AppColors.error : context.eco,
                      ),
                      MoneyRow(
                        label: context.tr('Thrown away (at cost)'),
                        value: formatRM(vm.wasteSen),
                      ),
                      if (t.unitsWithoutCost > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            context.tr(
                              '{count} item(s) sold have no cost price, so '
                              'the profit leaves them out.',
                              {'count': t.unitsWithoutCost},
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SectionHeader(title: context.tr('Count the cash drawer')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _float,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.tr('Cash at opening (float)'),
                          helperText: context.tr(
                            'The change you put in the drawer this morning',
                          ),
                          prefixText: 'RM ',
                        ),
                        onChanged: (v) {
                          _floatTyped = true;
                          vm.setFloat(parseRMToSen(v) ?? 0);
                        },
                      ),
                      const SizedBox(height: 12),
                      for (final note in CloseShopViewModel.notes)
                        _NoteRow(
                          note: note,
                          controller: _notes[note]!,
                          count: vm.noteCount(note),
                          onChanged: (count) => vm.setNoteCount(note, count),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _coins,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.tr('Coins (total)'),
                          prefixText: 'RM ',
                        ),
                        onChanged: (v) => vm.setCoins(parseRMToSen(v) ?? 0),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Material(
            elevation: 8,
            color: context.colors.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoneyRow(
                    label: context.tr('Expected in drawer'),
                    value: formatRM(vm.expectedSen),
                  ),
                  MoneyRow(
                    label: context.tr('Counted'),
                    value: formatRM(vm.countedSen),
                  ),
                  MoneyRow(
                    label: diff == 0
                        ? context.tr('Cash matches ✓')
                        : context.tr('Difference'),
                    value: diff > 0 ? '+${formatRM(diff)}' : formatRM(diff),
                    bold: true,
                    color: diffColor,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: vm.busy ? null : _close,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(context.tr('Close shop')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "RM 10 × [ 7 ] = RM 70.00"
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.controller,
    required this.count,
    required this.onChanged,
  });

  final int note;
  final TextEditingController controller;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              'RM ${note ~/ 100}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Text('×'),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true, hintText: '0'),
              onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
            ),
          ),
          Expanded(
            child: Text(
              formatRM(note * count),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
