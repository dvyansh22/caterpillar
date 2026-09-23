import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vertical.dart';

/// A scheduled task. `etaMinutes` will come from the ML task-time model (P1) via
/// the backend; mocked here for the scaffold. (FR-TASK-1/2)
class OperatorTask {
  const OperatorTask({
    required this.id,
    required this.name,
    required this.etaMinutes,
    required this.location,
    this.status = 'Scheduled',
  });

  final String id;
  final String name;
  final int etaMinutes;
  final String location;
  final String status;
}

/// Mock task list, vertical-aware. TODO(P4): back with Firestore + ml_client ETAs.
final tasksProvider = Provider<List<OperatorTask>>((ref) {
  final vertical = ref.watch(verticalProvider);
  final types = vertical.taskTypes;
  final locations = vertical == Vertical.mining
      ? ['Pit A — Bench 3', 'Haul Road 2', 'Dump Zone 1', 'Ramp 4', 'Stockpile B']
      : ['Sector 4 — Grid C', 'North Trench Line', 'Yard Bay 2', 'Pad 7', 'Block D'];
  final etas = [58, 45, 30, 35, 90];

  return [
    for (var i = 0; i < types.length; i++)
      OperatorTask(
        id: 'T00${i + 1}',
        name: types[i],
        etaMinutes: etas[i % etas.length],
        location: locations[i % locations.length],
        status: i == 0 ? 'Next' : 'Scheduled',
      ),
  ];
});
