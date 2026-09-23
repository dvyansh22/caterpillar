/// Riverpod providers for the AR bridge.
library;


import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ar_bridge_service.dart';
import 'ar_message.dart';

/// The AR bridge service instance (mock until Unity is wired).
final arBridgeProvider = Provider<ArBridgeService>((ref) {
  final service = MockArBridgeService();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of AR events from Unity.
final arEventsProvider = StreamProvider<ArEvent>((ref) {
  final bridge = ref.watch(arBridgeProvider);
  return bridge.events;
});

/// Whether the AR engine is loaded and ready.
final arReadyProvider = Provider<bool>((ref) {
  return ref.watch(arBridgeProvider).isReady;
});

/// Tracking status for each AR object — maps objectId → tracked.
final arTrackingStatusProvider =
    NotifierProvider<ArTrackingNotifier, Map<String, bool>>(ArTrackingNotifier.new);

class ArTrackingNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    // Update tracking state from AR events for this provider's lifetime.
    final sub = ref.listen(arEventsProvider, (_, next) {
      next.whenData((event) {
        if (event is TrackingStatusEvent) {
          update(event.objectId, event.tracked);
        }
      });
    });
    ref.onDispose(sub.close);
    return {};
  }

  void update(String objectId, bool tracked) {
    state = {...state, objectId: tracked};
  }

  void reset() => state = {};
}
