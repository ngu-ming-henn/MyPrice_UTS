import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../l10n/strings.dart';

/// "How did they pay?" when staff take the money (counter sale, pickup).
/// Returns PaymentMethod.cash or PaymentMethod.qr; null for Back. Close
/// shop counts only the cash in the drawer, so this choice matters.
Future<String?> askPayment(
  BuildContext context, {
  required String title,
  required String message,
}) => showDialog<String>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text(context.tr('Back')),
      ),
      FilledButton.tonalIcon(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
        onPressed: () => Navigator.pop(ctx, PaymentMethod.qr),
        icon: const Icon(Icons.qr_code_2),
        label: Text(context.tr(PaymentMethod.label(PaymentMethod.qr))),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
        onPressed: () => Navigator.pop(ctx, PaymentMethod.cash),
        icon: const Icon(Icons.payments_outlined),
        label: Text(context.tr(PaymentMethod.label(PaymentMethod.cash))),
      ),
    ],
  ),
);
