/// Real Unity↔Flutter AR bridge (production path).
///
/// This is the implementation used once the Unity project in `ar/` has been
/// exported into `ios/UnityLibrary` + `android/unityLibrary` and the
/// `flutter_unity_widget` dependency is enabled in `pubspec.yaml`.
///
/// It is intentionally **decoupled** from `flutter_unity_widget` so the app
/// compiles and runs today (mock mode) without the native Unity export. The
/// widget layer that actually embeds `UnityWidget` injects two thin handles:
///
///   * [attachPostMessage] — wires Unity's `UnityWidgetController.postMessage`
///     so [send] can deliver commands to the `ArBridge` GameObject.
///   * [onUnityMessage]     — call this from `UnityWidget.onUnityMessage`.
///
/// Wiring example (add to a `UnityArView` widget after enabling the package):
/// ```dart
/// UnityWidget(
///   onUnityCreated: (c) => bridge.attachPostMessage(
///     (go, method, msg) => c.postMessage(go, method, msg),
///   ),
///   onUnityMessage: bridge.onUnityMessage,
/// )
/// ```
///
/// Contract: P3 ↔ P4 (AGENTS.md interface contract #4).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ar_bridge_service.dart';
import 'ar_message.dart';

/// Signature of `UnityWidgetController.postMessage(gameObject, method, message)`.
typedef UnityPostMessage = Future<void> Function(
  String gameObject,
  String method,
  String message,
);

/// Name of the Unity GameObject that hosts `ArBridge.cs`.
const String _kArBridgeGameObject = 'ArBridge';

/// Method on `ArBridge.cs` that receives Flutter → Unity messages.
const String _kReceiveMethod = 'ReceiveMessage';

/// AR bridge backed by a real embedded Unity engine.
class UnityArBridgeService implements ArBridgeService {
  UnityArBridgeService();

  UnityPostMessage? _postMessage;
  final _eventController = StreamController<ArEvent>.broadcast();
  bool _isReady = false;

  @override
  Stream<ArEvent> get events => _eventController.stream;

  @override
  bool get isReady => _isReady;

  /// Injected by the `UnityWidget` host once Unity is created.
  void attachPostMessage(UnityPostMessage postMessage) {
    _postMessage = postMessage;
  }

  /// Call from `UnityWidget.onUnityMessage`. Parses the JSON envelope emitted
  /// by `ArBridge.SendEventToFlutter` and republishes it as a typed [ArEvent].
  void onUnityMessage(dynamic message) {
    if (message == null) return;
    try {
      final decoded = jsonDecode(message.toString());
      if (decoded is! Map<String, dynamic>) return;
      final event = ArEvent.fromJson(decoded);
      if (event is EngineReadyEvent) _isReady = true;
      _eventController.add(event);
    } catch (e) {
      debugPrint('[UnityArBridge] Failed to parse Unity message: $e');
    }
  }

  @override
  Future<void> send(ArCommand command) async {
    final post = _postMessage;
    if (post == null) {
      debugPrint(
        '[UnityArBridge] Dropping ${command.type}: Unity not attached yet.',
      );
      return;
    }
    await post(_kArBridgeGameObject, _kReceiveMethod, command.encode());
  }

  @override
  void dispose() {
    _isReady = false;
    _postMessage = null;
    _eventController.close();
  }
}
