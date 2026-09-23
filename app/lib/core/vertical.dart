import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two operating verticals. One app, two personalities — this drives theming,
/// task vocabulary, and (later) safety rules and training catalog. Never hardcode
/// per-vertical behavior elsewhere; read it from [verticalProvider].
enum Vertical {
  construction(
    label: 'Construction',
    accent: Color(0xFFFFCD11), // safety yellow
    taskTypes: ['Earth Excavation', 'Trenching', 'Material Loading', 'Grading', 'Demolition'],
  ),
  mining(
    label: 'Mining',
    accent: Color(0xFFF26522), // safety orange
    taskTypes: ['Load-Haul-Dump', 'Haul Cycle', 'Bench Loading', 'Dozing', 'Road Maintenance'],
  );

  const Vertical({required this.label, required this.accent, required this.taskTypes});

  final String label;
  final Color accent;
  final List<String> taskTypes;
}

class VerticalNotifier extends Notifier<Vertical> {
  @override
  Vertical build() => Vertical.construction;

  void set(Vertical v) => state = v;

  void toggle() =>
      state = state == Vertical.construction ? Vertical.mining : Vertical.construction;
}

final verticalProvider = NotifierProvider<VerticalNotifier, Vertical>(VerticalNotifier.new);
