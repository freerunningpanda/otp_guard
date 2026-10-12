import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A `Listenable` that notifies when its source emits a state.
///
/// The router wants a `Listenable` to know when to check its redirects again,
/// and a cubit has a stream.
class CubitListenable extends ChangeNotifier {
  /// Starts to follow [source].
  CubitListenable(StateStreamable<Object?> source) {
    _subscription = source.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
