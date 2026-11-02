import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A counter bumped whenever data that feeds personalised content changes:
/// favorites, client profile preferences, orders.
///
/// Providers that depend on that data (e.g. the recommendations) `watch`
/// this, so they recompute without an app restart.
///
/// Module 1 bumps it after favorites and profile updates.  Any module that
/// writes such data — Module 2 after saving an order — calls:
///
/// ```dart
/// ref.read(userDataChangesProvider.notifier).changed();
/// ```
class UserDataChangesNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Signals that favorites, preferences or orders changed.
  void changed() => state++;
}

final userDataChangesProvider =
    NotifierProvider<UserDataChangesNotifier, int>(UserDataChangesNotifier.new);
