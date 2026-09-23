/// Core Riverpod providers — vertical state, navigation, and AR state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config.dart';

/// Current operational vertical (construction / mining).
/// Drives theme, task types, safety rules, training catalog.
final verticalProvider = StateProvider<Vertical>((ref) => Vertical.construction);

/// Currently selected bottom-nav tab index.
final selectedTabProvider = StateProvider<int>((ref) => 0);
