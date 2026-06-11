import 'package:flutter/foundation.dart';

/// Global manager for monitoring network / server connection state.
class ConnectionManager {
  ConnectionManager._();
  static final instance = ConnectionManager._();

  /// Emits true when network or server connection is lost, and false when restored.
  final connectionLost = ValueNotifier<bool>(false);

  /// Updates the connection state.
  void setLost(bool lost) {
    if (connectionLost.value != lost) {
      connectionLost.value = lost;
    }
  }
}
