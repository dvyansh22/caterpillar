/// Riverpod providers for the ML client.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ml_client.dart';

/// The ML client singleton.
final mlClientProvider = Provider<MlClient>((ref) {
  final client = MlClient();
  ref.onDispose(client.dispose);
  return client;
});
