import 'package:flutter/foundation.dart';

/// Global notifier. Increment to signal that a transaction was created/deleted
/// so that any listening widget (e.g. HomeScreen) can refresh itself.
final transactionNotifier = ValueNotifier<int>(0);

void notifyTransactionChanged() => transactionNotifier.value++;
