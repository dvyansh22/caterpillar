import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../services/ml_client/ml_providers.dart';

// ---------------------------------------------------------------------------
// Owner / fleet dashboard (web) — "Night Shift" dark design.
// Live data: fleet + idle from the ML backend, incidents + training from
// Firestore (with per-source seed fallback). See dashSiteProvider below.
// ---------------------------------------------------------------------------

enum DashTab { overview, fleet, incidents, training }

final dashTabProvider = NotifierProvider<_DashTabNotifier, DashTab>(_DashTabNotifier.new);

class _DashTabNotifier extends Notifier<DashTab> {
  @override
  DashTab build() => DashTab.overview;
  void set(DashTab t) => state = t;
}

final dashVerticalProvider = NotifierProvider<_DashVerticalNotifier, Vertical>(_DashVerticalNotifier.new);

class _DashVerticalNotifier extends Notifier<Vertical> {
  @override
  Vertical build() => Vertical.construction;
  void set(Vertical v) => state = v;
}

// ---------------------------------------------------------------------------
// Dashboard interaction state (NotifierProviders local to this screen).
// ---------------------------------------------------------------------------

enum IncidentFilter { all, safety, observations }

/// Machine whose right drawer is open (Fleet + Overview).
final drawerMachineIdProvider = NotifierProvider<_NullStrNotifier, String?>(_NullStrNotifier.new);

/// Overview "Incidents by machine": which machine row is expanded (one at a time).
final expandedMachineIdProvider = NotifierProvider<_NullStrNotifier, String?>(_NullStrNotifier.new);

/// Incidents tab: which single incident log is expanded (one at a time).
final openIncidentIdProvider = NotifierProvider<_NullStrNotifier, String?>(_NullStrNotifier.new);

class _NullStrNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
  void toggle(String v) => state = state == v ? null : v;
}

/// Incidents tab: machine ids whose older history is revealed.
final incidentHistoryProvider = NotifierProvider<_StrSetNotifier, Set<String>>(_StrSetNotifier.new);

class _StrSetNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void toggle(String v) => state = state.contains(v) ? ({...state}..remove(v)) : {...state, v};
  void add(String v) => state = {...state, v};
  void reset() => state = const {};
}

/// Incidents tab: active severity filter.
final incidentFilterProvider = NotifierProvider<_FilterNotifier, IncidentFilter>(_FilterNotifier.new);

class _FilterNotifier extends Notifier<IncidentFilter> {
  @override
  IncidentFilter build() => IncidentFilter.all;
  void set(IncidentFilter f) => state = f;
}

// ---------------------------------------------------------------------------
// View models (extended for the Night Shift design; live wiring preserved).
// ---------------------------------------------------------------------------

enum MStatus { inUse, idle, offline }

class Machine {
  const Machine(
    this.id,
    this.type,
    this.operator,
    this.status,
    this.phoneFed,
    this.alerts, {
    this.opId = '',
    this.lastTask = '',
    this.idlePct = -1,
  });
  final String id, type, operator;
  final MStatus status;
  final bool phoneFed; // true = phone sensors (no telematics), false = telematics
  final int alerts;
  final String opId, lastTask;
  final int idlePct; // -1 = unknown/offline
}

class IncidentRow {
  const IncidentRow(
    this.severity,
    this.text,
    this.machine,
    this.time, {
    this.operator = '',
    this.opId = '',
    this.location = '',
    this.gps = '',
    this.transcript = '',
    this.detail = '',
  });
  final String severity; // safety | anomaly | observation  (== kind)
  final String text, machine, time;
  final String operator, opId, location, gps, transcript, detail;

  /// Stable id within a site (used for cross-tab "open this log" jumps).
  String get id => '$machine|$time|$text';
}

class TrainingRow {
  const TrainingRow(this.operator, this.done, this.total, this.score, {this.opId = '', this.machineId = ''});
  final String operator;
  final int done, total;
  final int? score;
  final String opId, machineId;
}

class _Site {
  const _Site(this.name, this.machines, this.incidents, this.idleWeek, this.training);
  final String name;
  final List<Machine> machines;
  final List<IncidentRow> incidents;
  final List<int> idleWeek;
  final List<TrainingRow> training;
}

const _construction = _Site(
  'SITE01 · Metro depot',
  [
    Machine('EXC004', 'Cat 320 Excavator', 'Arjun Kumar', MStatus.inUse, true, 2,
        opId: 'OP1001', lastTask: 'Trenching · Zone B', idlePct: 18),
    Machine('LDR003', 'Cat 950 Loader', 'Ravi Shankar', MStatus.inUse, true, 1,
        opId: 'OP1006', lastTask: 'Material loading · Stockpile 2', idlePct: 24),
    Machine('DZR004', 'Cat D6 Dozer', 'Suresh Iyer', MStatus.inUse, false, 0,
        opId: 'OP1008', lastTask: 'Grading · Access road', idlePct: 31),
    Machine('GRD002', 'Cat 140 Grader', 'Priya Nair', MStatus.idle, false, 0,
        opId: 'OP1004', lastTask: 'Fine grading · Pad C', idlePct: 40),
    Machine('TRK006', 'Cat 730 Truck', 'Manoj Das', MStatus.inUse, false, 0,
        opId: 'OP1013', lastTask: 'Haul · Spoil bank', idlePct: 15),
    Machine('BHL005', 'Cat 432 Backhoe', 'Kiran Rao', MStatus.inUse, true, 0,
        opId: 'OP1011', lastTask: 'Utility dig · Bay 4', idlePct: 22),
    Machine('SKD007', 'Cat 262 Skid Steer', 'Unassigned', MStatus.offline, true, 0),
    Machine('PVR008', 'Cat AP500 Paver', 'Unassigned', MStatus.offline, false, 0),
  ],
  [
    IncidentRow('safety', 'Ground crew behind swing radius', 'EXC004', 'Today 14:02',
        operator: 'Arjun Kumar',
        opId: 'OP1001',
        location: 'Zone B · Trench line',
        gps: '12.9716 N, 77.5946 E',
        detail: 'Ground crew detected inside the swing radius during a slew. Operator alerted, machine paused.'),
    IncidentRow('observation', 'Soft soil at trench edge, cave-in risk', 'EXC004', 'Today 13:41',
        operator: 'Arjun Kumar',
        opId: 'OP1001',
        location: 'Zone B · Trench line',
        gps: '12.9716 N, 77.5946 E',
        transcript: 'Soil on the north edge is loose, keeping the bucket back from the lip until it is shored.'),
    IncidentRow('observation', 'Hydraulic whine on full bucket', 'EXC004', 'Today 10:12',
        operator: 'Arjun Kumar',
        opId: 'OP1001',
        location: 'Zone B · Trench line',
        transcript: 'Getting a whine from the hydraulics on a full bucket, logging it for the fitter.'),
    IncidentRow('anomaly', 'Excessive idling flagged', 'DZR004', 'Today 13:18',
        operator: 'Suresh Iyer',
        opId: 'OP1008',
        location: 'Access road',
        detail: 'Engine idled 42 min above the shift baseline. Behavior flag raised for review.'),
    IncidentRow('safety', 'Pedestrian proximity alert', 'BHL005', 'Today 11:55',
        operator: 'Kiran Rao',
        opId: 'OP1011',
        location: 'Bay 4',
        gps: '12.9722 N, 77.5931 E',
        detail: 'Worker crossed within 3 m of the reversing backhoe. Proximity alarm triggered.'),
    IncidentRow('safety', 'Unfastened seatbelt while moving', 'LDR003', 'Yest. 16:40',
        operator: 'Ravi Shankar',
        opId: 'OP1006',
        location: 'Stockpile 2',
        detail: 'Seatbelt unfastened with the loader in motion. Lesson assigned.'),
    IncidentRow('observation', 'Loose gravel on haul path', 'TRK006', 'Yest. 09:05',
        operator: 'Manoj Das',
        opId: 'OP1013',
        location: 'Spoil bank ramp',
        transcript: 'Path up to the spoil bank is loose, could use a grader pass before the next haul cycle.'),
  ],
  [28, 22, 31, 19, 24, 15, 22],
  [
    TrainingRow('Arjun Kumar', 2, 3, 92, opId: 'OP1001', machineId: 'EXC004'),
    TrainingRow('Priya Nair', 3, 3, 95, opId: 'OP1004', machineId: 'GRD002'),
    TrainingRow('Ravi Shankar', 2, 3, 84, opId: 'OP1006', machineId: 'LDR003'),
    TrainingRow('Suresh Iyer', 1, 2, 71, opId: 'OP1008', machineId: 'DZR004'),
    TrainingRow('Kiran Rao', 3, 3, 89, opId: 'OP1011', machineId: 'BHL005'),
    TrainingRow('Manoj Das', 3, 4, 86, opId: 'OP1013', machineId: 'TRK006'),
  ],
);

const _mining = _Site(
  'SITE03 · North pit',
  [
    Machine('HT012', 'Cat 777 Haul Truck', 'Bala Murugan', MStatus.inUse, false, 1,
        opId: 'OP2001', lastTask: 'Haul · Ramp R2', idlePct: 16),
    Machine('SH02', 'Cat 6040 Hydraulic Shovel', 'Venkat Raman', MStatus.inUse, false, 0,
        opId: 'OP2003', lastTask: 'Loading · Bench 395', idlePct: 12),
    Machine('HT009', 'Cat 777 Haul Truck', 'Dinesh Kumar', MStatus.inUse, true, 1,
        opId: 'OP2004', lastTask: 'Haul · Crusher', idlePct: 20),
    Machine('LV03', 'Light Vehicle', 'Anand Pillai', MStatus.inUse, true, 0,
        opId: 'OP2006', lastTask: 'Site inspection', idlePct: 27),
    Machine('DR07', 'Cat MD6250 Drill', 'Gopal Reddy', MStatus.idle, false, 0,
        opId: 'OP2008', lastTask: 'Drilling · Pattern 7', idlePct: 44),
    Machine('DZ08', 'Cat D10 Dozer', 'Senthil Nathan', MStatus.inUse, true, 0,
        opId: 'OP2011', lastTask: 'Dozing · Dump 3', idlePct: 21),
    Machine('HT015', 'Cat 777 Haul Truck', 'Unassigned', MStatus.offline, true, 0),
    Machine('WL05', 'Cat 992 Wheel Loader', 'Unassigned', MStatus.offline, false, 0),
  ],
  [
    IncidentRow('safety', 'Unfastened seatbelt + fatigue', 'HT012', 'Today 14:26',
        operator: 'Bala Murugan',
        opId: 'OP2001',
        location: 'Ramp R2 · km 1.4',
        gps: '23.7461 S, 133.8770 E',
        detail: 'Seatbelt unfastened while fatigue signs were detected on-camera. Rest break enforced.'),
    IncidentRow('observation', 'Rough patch on ramp R2, km 1.4', 'HT012', 'Today 12:55',
        operator: 'Bala Murugan',
        opId: 'OP2001',
        location: 'Ramp R2 · km 1.4',
        gps: '23.7461 S, 133.8770 E',
        transcript: 'Rough patch on the ramp around km 1.4, jolting the loaded truck, flag it for the grader.'),
    IncidentRow('anomaly', 'Harsh loaded turn flagged', 'HT012', 'Today 10:40',
        operator: 'Bala Murugan',
        opId: 'OP2001',
        location: 'Ramp R2',
        detail: 'Lateral g above threshold on a loaded turn. Behavior flag raised.'),
    IncidentRow('safety', 'Light vehicle in blind spot at crusher', 'HT009', 'Today 12:37',
        operator: 'Dinesh Kumar',
        opId: 'OP2004',
        location: 'Crusher tip',
        gps: '23.7488 S, 133.8802 E',
        detail: 'Light vehicle entered the haul truck blind spot at the crusher. Proximity alert fired.'),
    IncidentRow('observation', 'Brakes soft on a loaded descent', 'HT009', 'Yest. 09:15',
        operator: 'Dinesh Kumar',
        opId: 'OP2004',
        location: 'Ramp R2 descent',
        transcript: 'Brakes feel a bit soft on the loaded descent, want the fitter to take a look end of shift.'),
    IncidentRow('observation', 'Dust limiting visibility at bench 395', 'DR07', 'Yest. 08:48',
        operator: 'Gopal Reddy',
        opId: 'OP2008',
        location: 'Bench 395',
        transcript: 'Dust is limiting visibility up on bench 395, water cart should do another pass.'),
  ],
  [18, 24, 20, 27, 22, 16, 21],
  [
    TrainingRow('Bala Murugan', 2, 2, 93, opId: 'OP2001', machineId: 'HT012'),
    TrainingRow('Venkat Raman', 1, 2, 85, opId: 'OP2003', machineId: 'SH02'),
    TrainingRow('Dinesh Kumar', 2, 2, 90, opId: 'OP2004', machineId: 'HT009'),
    TrainingRow('Anand Pillai', 1, 2, 80, opId: 'OP2006', machineId: 'LV03'),
    TrainingRow('Gopal Reddy', 0, 2, null, opId: 'OP2008', machineId: 'DR07'),
  ],
);

/// Live dashboard data: fleet + idle from the model backend (`/ml/fleet`, which
/// simulates live variation), incidents + training from Firestore. Polls every
/// 6s so the fleet animates and newly-logged incidents appear without a reload.
/// Falls back to the seed site for any piece the backend/Firestore can't provide.
final dashSiteProvider = StreamProvider.autoDispose.family<_Site, Vertical>((ref, vertical) async* {
  final vs = vertical == Vertical.mining ? 'mining' : 'construction';
  final seed = vertical == Vertical.mining ? _mining : _construction;
  final repo = ref.read(dataRepositoryProvider);

  Future<_Site> load() async {
    final fleet = await ref.read(mlClientProvider).getFleet(vs); // null if backend down
    List<IncidentRecord> incidents = const [];
    List<TrainingRecord> training = const [];
    try {
      incidents = await repo.readIncidents(vertical);
    } catch (_) {}
    try {
      training = await repo.readTraining(vertical);
    } catch (_) {}

    final machines = fleet == null
        ? seed.machines
        : [
            for (final m in fleet.machines)
              Machine(m.id, m.type, m.operator, _status(m.status), m.phoneFed, m.alerts),
          ];
    final idleWeek = (fleet != null && fleet.idleWeek.length == 7) ? fleet.idleWeek : seed.idleWeek;
    final incidentRows = incidents.isEmpty
        ? seed.incidents
        : [
            for (final i in incidents)
              IncidentRow(
                i.kind ?? i.severity,
                i.text,
                i.machineId,
                i.time,
                operator: i.operatorId,
                opId: i.operatorId,
                location: i.location,
                gps: i.gps,
                // Live logs are voice observations; keep the transcript for detail.
                transcript: (i.kind ?? i.severity) == 'observation' ? i.transcript : '',
              ),
          ];
    final trainingRows = training.isEmpty ? seed.training : _aggregateTraining(training);
    return _Site(seed.name, machines, incidentRows, idleWeek, trainingRows);
  }

  yield await load();
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 6))) {
    yield await load();
  }
});

MStatus _status(String s) => switch (s) {
      'idle' => MStatus.idle,
      'offline' => MStatus.offline,
      _ => MStatus.inUse,
    };

List<TrainingRow> _aggregateTraining(List<TrainingRecord> recs) {
  final byOp = <String, List<TrainingRecord>>{};
  for (final r in recs) {
    byOp.putIfAbsent(r.operatorId, () => []).add(r);
  }
  return [
    for (final e in byOp.entries)
      TrainingRow(
        e.key,
        e.value.length,
        math.max(e.value.length, 3), // assume a 3-module catalog
        (e.value.map((r) => r.score).reduce((a, b) => a + b) / e.value.length).round(),
        opId: e.key,
      ),
  ];
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Color _dotColor(String kind) => switch (kind) {
      'safety' => AppColors.danger,
      'anomaly' => AppColors.anomalyDot,
      _ => AppColors.observationDot,
    };

String _kindLabel(String kind) => switch (kind) {
      'safety' => 'SAFETY ALERT',
      'anomaly' => 'UNUSUAL BEHAVIOR',
      _ => 'VOICE OBSERVATION',
    };

/// Machine ids in newest-incident-first order (list is already newest-first).
List<String> _machineOrder(List<IncidentRow> incs) {
  final seen = <String>[];
  for (final i in incs) {
    if (!seen.contains(i.machine)) seen.add(i.machine);
  }
  return seen;
}

List<IncidentRow> _logsFor(List<IncidentRow> incs, String machineId) =>
    [for (final i in incs) if (i.machine == machineId) i];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vertical = ref.watch(dashVerticalProvider);
    final tab = ref.watch(dashTabProvider);
    final acc = vertical.accent;
    final siteAsync = ref.watch(dashSiteProvider(vertical));
    final live = siteAsync.hasValue;
    final site = siteAsync.asData?.value ?? (vertical == Vertical.mining ? _mining : _construction);
    final drawerId = ref.watch(drawerMachineIdProvider);
    final drawerMachine = drawerId == null
        ? null
        : site.machines.where((m) => m.id == drawerId).cast<Machine?>().firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _TopBar(vertical: vertical, tab: tab, acc: acc, live: live),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 40, 32, 56),
                        child: switch (tab) {
                          DashTab.overview => _Overview(site: site, acc: acc),
                          DashTab.fleet => _FleetPage(site: site, acc: acc),
                          DashTab.incidents => _IncidentsTab(site: site, acc: acc),
                          DashTab.training => _Training(site: site, acc: acc),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (drawerMachine != null)
            _MachineDrawer(machine: drawerMachine, site: site, acc: acc),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.vertical, required this.tab, required this.acc, required this.live});
  final Vertical vertical;
  final DashTab tab;
  final AccentPalette acc;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goTab(DashTab t) {
      ref.read(dashTabProvider.notifier).set(t);
      ref.read(drawerMachineIdProvider.notifier).set(null); // tabs close the drawer
    }

    Widget tabBtn(DashTab t, String label) {
      final active = tab == t;
      return InkWell(
        onTap: () => goTab(t),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: IntrinsicWidth(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 21),
                Text(label.toUpperCase(),
                    style: oswald(
                        size: 14,
                        weight: FontWeight.w500,
                        spacing: 1.4,
                        color: active ? AppColors.ink : AppColors.mutedDash)),
                const Spacer(),
                Container(height: 3, width: double.infinity, color: active ? acc.base : Colors.transparent),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: acc.base, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.precision_manufacturing, size: 18, color: AppColors.onAccent),
          ),
          const SizedBox(width: 10),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'SMART OPERATOR', style: oswald(size: 16, weight: FontWeight.w600, spacing: 1, color: AppColors.ink)),
            TextSpan(text: '  ·  FLEET', style: oswald(size: 16, weight: FontWeight.w600, spacing: 1, color: AppColors.mutedDash)),
          ])),
          const SizedBox(width: 12),
          _LiveBadge(live: live),
          const SizedBox(width: 20),
          tabBtn(DashTab.overview, 'Overview'),
          tabBtn(DashTab.fleet, 'Fleet'),
          tabBtn(DashTab.incidents, 'Incidents'),
          tabBtn(DashTab.training, 'Training'),
          const Spacer(),
          _VerticalToggle(vertical: vertical, acc: acc),
          const SizedBox(width: 12),
          _OwnerPill(vertical: vertical, acc: acc),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(navProvider.notifier).reset(),
            icon: const Icon(Icons.logout, size: 18, color: AppColors.mutedDash),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.live});
  final bool live;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: live ? AppColors.successBg : AppColors.surface2,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: live ? AppColors.successInk : AppColors.mutedDash, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(live ? 'LIVE' : 'LOADING',
              style: oswald(
                  size: 11,
                  weight: FontWeight.w600,
                  spacing: 0.9,
                  color: live ? AppColors.successInk : AppColors.mutedDash)),
        ],
      ),
    );
  }
}

class _VerticalToggle extends ConsumerWidget {
  const _VerticalToggle({required this.vertical, required this.acc});
  final Vertical vertical;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(Vertical v) {
      ref.read(dashVerticalProvider.notifier).set(v);
      // Switching site resets the drawer, expanded rows, history and filters.
      ref.read(drawerMachineIdProvider.notifier).set(null);
      ref.read(expandedMachineIdProvider.notifier).set(null);
      ref.read(openIncidentIdProvider.notifier).set(null);
      ref.read(incidentHistoryProvider.notifier).reset();
      ref.read(incidentFilterProvider.notifier).set(IncidentFilter.all);
    }

    Widget seg(Vertical v, String label) {
      final on = vertical == v;
      return InkWell(
        onTap: () => select(v),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: on ? AppColors.ink : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: v.accent.base, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label.toUpperCase(),
                  style: oswald(size: 12, weight: FontWeight.w500, spacing: 0.8, color: on ? AppColors.onAccent : AppColors.mutedDash)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [seg(Vertical.construction, 'Construction'), const SizedBox(width: 2), seg(Vertical.mining, 'Mining')]),
    );
  }
}

class _OwnerPill extends StatelessWidget {
  const _OwnerPill({required this.vertical, required this.acc});
  final Vertical vertical;
  final AccentPalette acc;
  @override
  Widget build(BuildContext context) {
    final name = vertical == Vertical.mining ? 'Eswar Prasad' : 'Deepa Menon';
    final initial = name[0];
    return Container(
      height: 34,
      padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(17)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: acc.base, shape: BoxShape.circle),
            child: Text(initial, style: oswald(size: 12, weight: FontWeight.w700, color: AppColors.onAccent)),
          ),
          const SizedBox(width: 8),
          Text(name, style: inter(size: 13, color: AppColors.ink2)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page header: hazard-stripe kicker + H1
// ---------------------------------------------------------------------------

class _HazardStripes extends StatelessWidget {
  const _HazardStripes({required this.color, this.width = 32, this.height = 8});
  final Color color;
  final double width, height;
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height, child: CustomPaint(painter: _StripePainter(color)));
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final p = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    for (double x = -size.height; x < size.width + size.height; x += 9) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) => old.color != color;
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text, this.acc);
  final String text;
  final AccentPalette acc;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HazardStripes(color: acc.base),
        const SizedBox(width: 10),
        Text(text.toUpperCase(), style: oswald(size: 13, weight: FontWeight.w600, spacing: 1.6, color: acc.ink)),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.kicker, required this.title, this.subline, required this.acc});
  final String kicker, title;
  final String? subline;
  final AccentPalette acc;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Kicker(kicker, acc),
        const SizedBox(height: 12),
        Text(title.toUpperCase(), style: oswald(size: 48, weight: FontWeight.w700, spacing: 0.4, height: 1.0, color: AppColors.ink)),
        if (subline != null) ...[
          const SizedBox(height: 10),
          Text(subline!, style: inter(size: 15, color: AppColors.ink2)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card + tags + ring icon
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: AppColors.divider),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _RingIcon extends StatelessWidget {
  const _RingIcon(this.icon, this.acc, {this.danger = false});
  final IconData icon;
  final AccentPalette acc;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final c = danger ? AppColors.danger : acc.base;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1.5)),
      child: Icon(icon, size: 16, color: c),
    );
  }
}

Widget _statusTag(MStatus status, AccentPalette acc) {
  final (Color bg, Color border, Color ink, String label) = switch (status) {
    MStatus.inUse => (acc.base, acc.base, AppColors.onAccent, 'In use'),
    MStatus.idle => (AppColors.surface2, AppColors.surface2, AppColors.ink2, 'Idle'),
    MStatus.offline => (Colors.transparent, AppColors.strongBorder, AppColors.mutedDash, 'Offline'),
  };
  return Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11), border: Border.all(color: border)),
    child: Text(label.toUpperCase(), style: oswald(size: 11, weight: FontWeight.w600, spacing: 0.9, color: ink)),
  );
}

Widget _sourceTag(bool phone, AccentPalette acc) {
  final border = phone ? acc.base : AppColors.strongBorder;
  final ink = phone ? acc.ink : AppColors.ink2;
  return Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: border)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(phone ? Icons.smartphone : Icons.settings_input_antenna, size: 12, color: ink),
        const SizedBox(width: 5),
        Text((phone ? 'Phone sensors' : 'Telematics').toUpperCase(),
            style: oswald(size: 11, weight: FontWeight.w500, spacing: 0.8, color: ink)),
      ],
    ),
  );
}

Widget _countTag(int n) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.strongBorder)),
    child: Text('$n ${n == 1 ? 'LOG' : 'LOGS'}', style: oswald(size: 10, weight: FontWeight.w500, spacing: 0.8, color: AppColors.ink2)),
  );
}

Widget _cardTitle(String text) =>
    Text(text.toUpperCase(), style: oswald(size: 20, weight: FontWeight.w600, spacing: 0.6, color: AppColors.ink));

class _Link extends StatelessWidget {
  const _Link(this.text, this.acc, {required this.onTap});
  final String text;
  final AccentPalette acc;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text.toUpperCase(), style: oswald(size: 13, weight: FontWeight.w500, spacing: 1.2, color: acc.ink)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 15, color: acc.base),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

class _Overview extends ConsumerWidget {
  const _Overview({required this.site, required this.acc});
  final _Site site;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = site.machines.where((m) => m.status != MStatus.offline).length;
    final phoneActive = site.machines.where((m) => m.status != MStatus.offline && m.phoneFed).length;
    final alerts = site.machines.fold<int>(0, (a, m) => a + m.alerts);
    final avgIdle = (site.idleWeek.reduce((a, b) => a + b) / site.idleWeek.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(kicker: '${site.name} · Wed 23 Sep', title: 'Fleet overview', acc: acc),
        Row(
          children: [
            Expanded(
                child: _KpiTile(
                    label: 'Active machines',
                    value: '$active',
                    suffix: ' / ${site.machines.length}',
                    foot: '$phoneActive via phone sensors',
                    icon: Icons.local_shipping_outlined,
                    acc: acc)),
            const SizedBox(width: 16),
            Expanded(
                child: _KpiTile(
                    label: 'Safety alerts today',
                    value: '$alerts',
                    foot: 'Across the fleet',
                    icon: Icons.gpp_maybe_outlined,
                    acc: acc,
                    danger: alerts > 0)),
            const SizedBox(width: 16),
            Expanded(
                child: _KpiTile(
                    label: 'Open incidents',
                    value: '${site.incidents.length}',
                    foot: 'Logged since 06:00',
                    icon: Icons.assignment_outlined,
                    acc: acc)),
            const SizedBox(width: 16),
            Expanded(
                child: _KpiTile(
                    label: 'Avg idle time',
                    value: '$avgIdle%',
                    foot: 'Fleet average · last 7 days',
                    icon: Icons.schedule_outlined,
                    acc: acc,
                    accentValue: true)),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 900;
          final left = _FleetTable(
            machines: site.machines.where((m) => m.status != MStatus.offline).toList(),
            acc: acc,
            title: 'Fleet status',
            trailing: _Link('View all ${site.machines.length}', acc,
                onTap: () => ref.read(dashTabProvider.notifier).set(DashTab.fleet)),
          );
          final right = _IncidentsByMachine(site: site, acc: acc);
          if (!wide) return Column(children: [left, const SizedBox(height: 24), right]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: right),
            ],
          );
        }),
        const SizedBox(height: 24),
        _IdleChart(week: site.idleWeek, acc: acc),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    this.suffix,
    this.foot,
    required this.icon,
    required this.acc,
    this.danger = false,
    this.accentValue = false,
  });
  final String label, value;
  final String? suffix, foot;
  final IconData icon;
  final AccentPalette acc;
  final bool danger, accentValue;

  @override
  Widget build(BuildContext context) {
    final valueColor = danger ? AppColors.danger : (accentValue ? acc.base : AppColors.ink);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    style: oswald(size: 12, weight: FontWeight.w500, spacing: 1.0, color: AppColors.mutedDash)),
              ),
              _RingIcon(icon, acc, danger: danger),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: oswald(size: 48, weight: FontWeight.w700, height: 1.0, color: valueColor).merge(kTabular)),
              if (suffix != null)
                Text(suffix!, style: oswald(size: 24, weight: FontWeight.w500, color: AppColors.mutedDash).merge(kTabular)),
            ],
          ),
          if (foot != null) ...[
            const SizedBox(height: 8),
            Text(foot!, style: inter(size: 13, color: AppColors.mutedDash)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fleet table (Overview subset + Fleet full page)
// ---------------------------------------------------------------------------

class _FleetTable extends ConsumerWidget {
  const _FleetTable({required this.machines, required this.acc, this.title, this.trailing});
  final List<Machine> machines;
  final AccentPalette acc;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerId = ref.watch(drawerMachineIdProvider);
    return _Card(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_cardTitle(title!), if (trailing != null) trailing!],
            ),
            const SizedBox(height: 14),
          ],
          _headerRow(),
          for (final m in machines)
            _MachineRow(
              machine: m,
              acc: acc,
              selected: drawerId == m.id,
              onTap: () => ref.read(drawerMachineIdProvider.notifier).toggle(m.id),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _headerRow() {
    Widget h(String t, int flex, {double? w, Alignment align = Alignment.centerLeft}) {
      final child = Align(
        alignment: align,
        child: Text(t.toUpperCase(), style: oswald(size: 12, weight: FontWeight.w500, spacing: 1.4, color: AppColors.mutedDash)),
      );
      return w != null ? SizedBox(width: w, child: child) : Expanded(flex: flex, child: child);
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          h('Machine', 5),
          h('Operator', 4),
          h('Status', 0, w: 88),
          h('Data source', 0, w: 150),
          h('Alerts', 0, w: 56, align: Alignment.centerRight),
        ],
      ),
    );
  }
}

class _MachineRow extends StatefulWidget {
  const _MachineRow({required this.machine, required this.acc, required this.selected, required this.onTap});
  final Machine machine;
  final AccentPalette acc;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_MachineRow> createState() => _MachineRowState();
}

class _MachineRowState extends State<_MachineRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final m = widget.machine;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (widget.selected || _hover) ? AppColors.cardHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: const Border(bottom: BorderSide(color: AppColors.dividerRow)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.id, style: mono(size: 13, weight: FontWeight.w500, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(m.type, style: inter(size: 13, color: AppColors.mutedDash), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(m.operator,
                    style: inter(size: 14, color: m.operator == 'Unassigned' ? AppColors.mutedDash : AppColors.ink),
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(width: 88, child: Align(alignment: Alignment.centerLeft, child: _statusTag(m.status, widget.acc))),
              SizedBox(width: 150, child: Align(alignment: Alignment.centerLeft, child: _sourceTag(m.phoneFed, widget.acc))),
              SizedBox(
                width: 56,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: m.alerts > 0
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('${m.alerts}', style: oswald(size: 16, weight: FontWeight.w600, color: AppColors.errorText).merge(kTabular)),
                        ])
                      : Text('—', style: oswald(size: 16, color: AppColors.faint)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fleet page
// ---------------------------------------------------------------------------

class _FleetPage extends StatelessWidget {
  const _FleetPage({required this.site, required this.acc});
  final _Site site;
  final AccentPalette acc;
  @override
  Widget build(BuildContext context) {
    final phone = site.machines.where((m) => m.phoneFed).length;
    final tele = site.machines.length - phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          kicker: site.name,
          title: 'Fleet',
          subline: '${site.machines.length} machines · $phone on phone sensors · $tele on telematics',
          acc: acc,
        ),
        _FleetTable(machines: site.machines, acc: acc),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Overview — Incidents by machine (expandable rows)
// ---------------------------------------------------------------------------

class _IncidentsByMachine extends ConsumerWidget {
  const _IncidentsByMachine({required this.site, required this.acc});
  final _Site site;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = _machineOrder(site.incidents).take(5).toList();
    final expanded = ref.watch(expandedMachineIdProvider);

    void jumpToIncident(IncidentRow row) {
      ref.read(dashTabProvider.notifier).set(DashTab.incidents);
      ref.read(drawerMachineIdProvider.notifier).set(null);
      ref.read(incidentHistoryProvider.notifier).add(row.machine);
      ref.read(openIncidentIdProvider.notifier).set(row.id);
    }

    return _Card(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Incidents by machine'),
          const SizedBox(height: 4),
          Text('Latest log per machine · click for history', style: inter(size: 13, color: AppColors.mutedDash)),
          const SizedBox(height: 12),
          for (final machineId in order)
            _OverviewIncidentRow(
              machineId: machineId,
              logs: _logsFor(site.incidents, machineId),
              acc: acc,
              expanded: expanded == machineId,
              onTapRow: () => ref.read(expandedMachineIdProvider.notifier).toggle(machineId),
              onTapHistory: jumpToIncident,
            ),
          const SizedBox(height: 8),
          _Link('View all incidents', acc, onTap: () => ref.read(dashTabProvider.notifier).set(DashTab.incidents)),
        ],
      ),
    );
  }
}

class _OverviewIncidentRow extends StatelessWidget {
  const _OverviewIncidentRow({
    required this.machineId,
    required this.logs,
    required this.acc,
    required this.expanded,
    required this.onTapRow,
    required this.onTapHistory,
  });
  final String machineId;
  final List<IncidentRow> logs;
  final AccentPalette acc;
  final bool expanded;
  final VoidCallback onTapRow;
  final void Function(IncidentRow) onTapHistory;

  @override
  Widget build(BuildContext context) {
    final latest = logs.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTapRow,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: expanded ? AppColors.cardHover : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: _dotColor(latest.severity), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(machineId, style: mono(size: 13, weight: FontWeight.w500, color: AppColors.ink)),
                        const SizedBox(width: 8),
                        _countTag(logs.length),
                      ]),
                      const SizedBox(height: 4),
                      Text(latest.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: inter(size: 14, color: AppColors.ink2)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(latest.time, style: mono(size: 12, color: AppColors.mutedDash)),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.expand_more, size: 18, color: AppColors.mutedDash),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 8),
            child: Column(
              children: [
                for (var i = 0; i < logs.length; i++)
                  InkWell(
                    onTap: () => onTapHistory(logs[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: i == logs.length - 1
                            ? null
                            : const Border(bottom: BorderSide(color: AppColors.strongBorder, style: BorderStyle.solid)),
                      ),
                      child: Row(
                        children: [
                          Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: _dotColor(logs[i].severity), shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(logs[i].text, style: inter(size: 14, color: AppColors.ink, height: 1.4)),
                                Text(_kindLabel(logs[i].severity),
                                    style: oswald(size: 11, weight: FontWeight.w500, spacing: 0.6, color: AppColors.mutedDash)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(logs[i].time, style: mono(size: 12, color: AppColors.mutedDash)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Idle chart (7 accent bars, hover shows value)
// ---------------------------------------------------------------------------

class _IdleChart extends StatefulWidget {
  const _IdleChart({required this.week, required this.acc});
  final List<int> week;
  final AccentPalette acc;
  @override
  State<_IdleChart> createState() => _IdleChartState();
}

class _IdleChartState extends State<_IdleChart> {
  int? _hover;
  @override
  Widget build(BuildContext context) {
    const days = ['Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Today'];
    final week = widget.week;
    final maxV = week.reduce((a, b) => a > b ? a : b).clamp(1, 100);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Idle time this week'),
          const SizedBox(height: 4),
          Text('Fleet average · last 7 days', style: inter(size: 13, color: AppColors.mutedDash)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // y-axis labels
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final l in ['40%', '20%', '0%'])
                        Text(l, style: oswald(size: 12, weight: FontWeight.w500, color: AppColors.mutedDash)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.strongBorder)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < week.length; i++)
                                Expanded(
                                  child: MouseRegion(
                                    onEnter: (_) => setState(() => _hover = i),
                                    onExit: (_) => setState(() => _hover = null),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          SizedBox(
                                            height: 16,
                                            child: _hover == i
                                                ? Text('${week[i]}%', style: oswald(size: 15, weight: FontWeight.w700, color: widget.acc.base).merge(kTabular))
                                                : null,
                                          ),
                                          const SizedBox(height: 4),
                                          Opacity(
                                            opacity: (_hover == null || _hover == i) ? 1 : 0.35,
                                            child: Container(
                                              constraints: const BoxConstraints(maxWidth: 72),
                                              height: 120 * (week[i] / maxV),
                                              decoration: BoxDecoration(
                                                  color: widget.acc.base,
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var i = 0; i < days.length; i++)
                            Expanded(
                              child: Center(
                                child: Text(days[i].toUpperCase(),
                                    style: oswald(
                                        size: 12,
                                        weight: i == days.length - 1 ? FontWeight.w600 : FontWeight.w500,
                                        color: i == days.length - 1 ? widget.acc.ink : AppColors.mutedDash)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incidents tab
// ---------------------------------------------------------------------------

class _IncidentsTab extends ConsumerWidget {
  const _IncidentsTab({required this.site, required this.acc});
  final _Site site;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(incidentFilterProvider);
    final all = site.incidents;
    final safety = all.where((i) => i.severity == 'safety' || i.severity == 'anomaly').toList();
    final obs = all.where((i) => i.severity == 'observation').toList();
    final visible = switch (filter) {
      IncidentFilter.all => all,
      IncidentFilter.safety => safety,
      IncidentFilter.observations => obs,
    };
    final machineById = {for (final m in site.machines) m.id: m};
    final order = _machineOrder(visible);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          kicker: site.name,
          title: 'Incidents',
          subline: 'Safety alerts and operator observations, grouped by machine. Newest first.',
          acc: acc,
        ),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 760;
          final filters = _IncidentFilters(
            acc: acc,
            active: filter,
            counts: {
              IncidentFilter.all: all.length,
              IncidentFilter.safety: safety.length,
              IncidentFilter.observations: obs.length,
            },
            onSelect: (f) => ref.read(incidentFilterProvider.notifier).set(f),
          );
          final groups = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final machineId in order) ...[
                _IncidentGroup(
                  machineId: machineId,
                  machine: machineById[machineId],
                  logs: _logsFor(visible, machineId),
                  acc: acc,
                ),
                const SizedBox(height: 20),
              ],
            ],
          );
          if (!wide) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [filters, const SizedBox(height: 20), groups]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 200, child: filters),
              const SizedBox(width: 24),
              Expanded(child: groups),
            ],
          );
        }),
      ],
    );
  }
}

class _IncidentFilters extends StatelessWidget {
  const _IncidentFilters({required this.acc, required this.active, required this.counts, required this.onSelect});
  final AccentPalette acc;
  final IncidentFilter active;
  final Map<IncidentFilter, int> counts;
  final void Function(IncidentFilter) onSelect;

  @override
  Widget build(BuildContext context) {
    Widget btn(IncidentFilter f, String label) {
      final on = active == f;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () => onSelect(f),
          borderRadius: BorderRadius.circular(kRadiusButton),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: on ? acc.tint : Colors.transparent,
              borderRadius: BorderRadius.circular(kRadiusButton),
              border: Border.all(color: on ? acc.base : AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label.toUpperCase(),
                      style: oswald(size: 14, weight: FontWeight.w500, spacing: 0.8, color: on ? acc.ink : AppColors.ink2)),
                ),
                Text('${counts[f] ?? 0}',
                    style: oswald(size: 14, weight: FontWeight.w600, color: on ? acc.ink : AppColors.mutedDash).merge(kTabular)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        btn(IncidentFilter.all, 'All'),
        btn(IncidentFilter.safety, 'Safety'),
        btn(IncidentFilter.observations, 'Observations'),
      ],
    );
  }
}

class _IncidentGroup extends ConsumerWidget {
  const _IncidentGroup({required this.machineId, required this.machine, required this.logs, required this.acc});
  final String machineId;
  final Machine? machine;
  final List<IncidentRow> logs;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyOpen = ref.watch(incidentHistoryProvider).contains(machineId);
    final openId = ref.watch(openIncidentIdProvider);
    final latest = logs.first;
    final older = logs.skip(1).toList();
    final type = machine?.type ?? '';
    final operator = machine?.operator ?? latest.operator;

    Widget logRow(IncidentRow row, {required bool isLatest}) {
      return _IncidentLogRow(
        row: row,
        type: type.isNotEmpty ? type : row.machine,
        acc: acc,
        isLatest: isLatest,
        expanded: openId == row.id,
        onTap: () => ref.read(openIncidentIdProvider.notifier).toggle(row.id),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(machineId, style: mono(size: 14, weight: FontWeight.w500, color: acc.ink)),
              const SizedBox(width: 8),
              if (type.isNotEmpty) Text(type, style: inter(size: 14, color: AppColors.ink)),
              if (operator.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(child: Text('· $operator', style: inter(size: 13, color: AppColors.mutedDash), overflow: TextOverflow.ellipsis)),
              ],
              const Spacer(),
              _countTag(logs.length),
            ],
          ),
        ),
        _Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              logRow(latest, isLatest: true),
              if (historyOpen)
                for (final row in older) ...[
                  const Divider(height: 1, color: AppColors.dividerRow),
                  logRow(row, isLatest: false),
                ],
              if (older.isNotEmpty)
                InkWell(
                  onTap: () => ref.read(incidentHistoryProvider.notifier).toggle(machineId),
                  child: Container(
                    height: 46,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.historyFooter,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(kRadiusCard)),
                      border: Border(top: BorderSide(color: AppColors.dividerRow)),
                    ),
                    child: Text(
                      historyOpen ? 'HIDE HISTORY' : 'SHOW HISTORY · ${older.length} EARLIER',
                      style: oswald(size: 13, weight: FontWeight.w500, spacing: 1.0, color: acc.ink),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IncidentLogRow extends StatelessWidget {
  const _IncidentLogRow({
    required this.row,
    required this.type,
    required this.acc,
    required this.isLatest,
    required this.expanded,
    required this.onTap,
  });
  final IncidentRow row;
  final String type;
  final AccentPalette acc;
  final bool isLatest, expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: _dotColor(row.severity), shape: BoxShape.circle)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.text, style: inter(size: 15, color: AppColors.ink, height: 1.35)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(_kindLabel(row.severity),
                              style: oswald(size: 11, weight: FontWeight.w500, spacing: 0.6, color: AppColors.mutedDash)),
                          if (isLatest) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: acc.base, borderRadius: BorderRadius.circular(4)),
                              child: Text('LATEST', style: oswald(size: 10, weight: FontWeight.w600, spacing: 0.6, color: AppColors.onAccent)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(row.time, style: mono(size: 12, color: AppColors.mutedDash)),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.expand_more, size: 18, color: AppColors.mutedDash),
                ),
              ],
            ),
          ),
        ),
        if (expanded) _IncidentDetail(row: row, type: type, acc: acc),
      ],
    );
  }
}

class _IncidentDetail extends StatelessWidget {
  const _IncidentDetail({required this.row, required this.type, required this.acc});
  final IncidentRow row;
  final String type;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _detailCell('Machine', '${row.machine}${type.isNotEmpty ? ' · $type' : ''}'),
      if (row.operator.isNotEmpty || row.opId.isNotEmpty)
        _detailCell('Operator', [row.operator, row.opId].where((s) => s.isNotEmpty).join('  ')),
      if (row.location.isNotEmpty) _detailCell('Location', row.location),
      if (row.gps.isNotEmpty) _detailCell('GPS', row.gps, isMono: true),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 32, runSpacing: 16, children: cells),
          if (row.severity == 'observation' && row.transcript.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.mic_none, size: 14, color: acc.base),
                    const SizedBox(width: 6),
                    Text('VOICE LOG TRANSCRIPT', style: oswald(size: 11, weight: FontWeight.w600, spacing: 0.8, color: acc.ink)),
                  ]),
                  const SizedBox(height: 8),
                  Text('“${row.transcript}”', style: inter(size: 15, color: AppColors.ink2, height: 1.5)),
                ],
              ),
            ),
          ],
          if (row.severity != 'observation' && row.detail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(row.detail, style: inter(size: 14, color: AppColors.ink2, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

Widget _detailCell(String label, String value, {bool isMono = false}) {
  return SizedBox(
    width: 200,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: oswald(size: 11, weight: FontWeight.w500, spacing: 0.8, color: AppColors.mutedDash)),
        const SizedBox(height: 4),
        isMono
            ? Text(value, style: mono(size: 14, color: AppColors.ink))
            : Text(value, style: inter(size: 14, color: AppColors.ink)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Machine drawer (right sheet)
// ---------------------------------------------------------------------------

class _MachineDrawer extends ConsumerWidget {
  const _MachineDrawer({required this.machine, required this.site, required this.acc});
  final Machine machine;
  final _Site site;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = _logsFor(site.incidents, machine.id);
    void close() => ref.read(drawerMachineIdProvider.notifier).set(null);

    void jump(IncidentRow row) {
      close();
      ref.read(dashTabProvider.notifier).set(DashTab.incidents);
      ref.read(incidentHistoryProvider.notifier).add(row.machine);
      ref.read(openIncidentIdProvider.notifier).set(row.id);
    }

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: close,
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: math.min(440, MediaQuery.of(context).size.width),
              height: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(left: BorderSide(color: AppColors.divider)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _HazardStripes(color: acc.base, width: 24, height: 8),
                        const SizedBox(width: 8),
                        Text(machine.id, style: mono(size: 14, weight: FontWeight.w500, color: acc.ink)),
                        const Spacer(),
                        InkWell(
                          onTap: close,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.strongBorder)),
                            child: const Icon(Icons.close, size: 18, color: AppColors.ink2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(machine.type.toUpperCase(),
                        style: oswald(size: 30, weight: FontWeight.w700, height: 1.05, color: AppColors.ink)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _statusTag(machine.status, acc),
                      const SizedBox(width: 8),
                      _sourceTag(machine.phoneFed, acc),
                    ]),
                    const SizedBox(height: 8),
                    if (machine.operator.isNotEmpty && machine.operator != 'Unassigned')
                      _drawerRow('Operator', [machine.operator, machine.opId].where((s) => s.isNotEmpty).join(' · ')),
                    if (machine.lastTask.isNotEmpty) _drawerRow('Last task', machine.lastTask),
                    _drawerRow('Idle today', machine.idlePct >= 0 ? '${machine.idlePct}%' : '—', big: true),
                    _drawerRowWidget(
                      'Open flags',
                      machine.alerts > 0
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('${machine.alerts} open flag${machine.alerts == 1 ? '' : 's'}',
                                  style: inter(size: 15, color: AppColors.ink)),
                            ])
                          : Text('None', style: inter(size: 15, color: AppColors.mutedDash)),
                    ),
                    // Incident log
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('INCIDENT LOG', style: oswald(size: 12, weight: FontWeight.w500, spacing: 1.0, color: AppColors.mutedDash)),
                              if (logs.isNotEmpty) _countTag(logs.length),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (logs.isEmpty)
                            Text('Nothing logged', style: inter(size: 15, color: AppColors.mutedDash))
                          else
                            for (final row in logs)
                              InkWell(
                                onTap: () => jump(row),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(color: _dotColor(row.severity), shape: BoxShape.circle)),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(row.text, style: inter(size: 14, color: AppColors.ink, height: 1.35))),
                                      const SizedBox(width: 8),
                                      Text(row.time, style: mono(size: 12, color: AppColors.mutedDash)),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _noteBox(machine.phoneFed, acc),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerRow(String label, String value, {bool big = false}) => _drawerRowWidget(
        label,
        Text(value,
            textAlign: TextAlign.right,
            style: big ? oswald(size: 20, weight: FontWeight.w700, color: AppColors.ink) : inter(size: 15, color: AppColors.ink)),
      );

  Widget _drawerRowWidget(String label, Widget value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.dividerRow))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label.toUpperCase(), style: oswald(size: 12, weight: FontWeight.w500, spacing: 1.0, color: AppColors.mutedDash)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
          ],
        ),
      );

  Widget _noteBox(bool phone, AccentPalette acc) {
    final text = phone
        ? 'No telematics hardware on this machine. Its data comes from the operator’s phone: camera, motion sensors, GPS and Bluetooth.'
        : 'Product Link telematics, plus the operator’s phone for seatbelt, fatigue and proximity.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: phone ? acc.base : AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: phone ? acc.base : AppColors.mutedDash),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: inter(size: 13, color: AppColors.ink2, height: 1.5))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Training
// ---------------------------------------------------------------------------

class _Training extends StatelessWidget {
  const _Training({required this.site, required this.acc});
  final _Site site;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context) {
    final done = site.training.fold<int>(0, (a, t) => a + t.done);
    final total = site.training.fold<int>(0, (a, t) => a + t.total);
    final pct = total == 0 ? 0 : (done / total * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          kicker: site.name,
          title: 'Training',
          subline: 'Lessons assigned after behavior flags, plus required modules',
          acc: acc,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('TEAM COMPLIANCE',
                          style: oswald(size: 12, weight: FontWeight.w500, spacing: 1.0, color: AppColors.mutedDash)),
                    ),
                    _RingIcon(Icons.school_outlined, acc),
                  ],
                ),
                const SizedBox(height: 14),
                Text('$pct%', style: oswald(size: 48, weight: FontWeight.w700, height: 1.0, color: acc.base).merge(kTabular)),
                const SizedBox(height: 8),
                Text('$done of $total assigned lessons complete', style: inter(size: 13, color: AppColors.mutedDash)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _Card(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _trainHeader(),
              for (final t in site.training) _TrainRow(row: t, acc: acc),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trainHeader() {
    Widget h(String t, int flex, {double? w, Alignment align = Alignment.centerLeft}) {
      final child = Align(
        alignment: align,
        child: Text(t.toUpperCase(), style: oswald(size: 12, weight: FontWeight.w500, spacing: 1.4, color: AppColors.mutedDash)),
      );
      return w != null ? SizedBox(width: w, child: child) : Expanded(flex: flex, child: child);
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          h('Operator', 4),
          h('Lessons', 5),
          h('Done', 0, w: 104),
          h('Latest score', 0, w: 96, align: Alignment.centerRight),
        ],
      ),
    );
  }
}

class _TrainRow extends StatelessWidget {
  const _TrainRow({required this.row, required this.acc});
  final TrainingRow row;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.dividerRow))),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.operator, style: inter(size: 15, weight: FontWeight.w500, color: AppColors.ink)),
                if (row.machineId.isNotEmpty || row.opId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text([row.machineId, row.opId].where((s) => s.isNotEmpty).join(' · '),
                      style: mono(size: 12, color: AppColors.mutedDash)),
                ],
              ],
            ),
          ),
          Expanded(flex: 5, child: _lessonBlocks()),
          SizedBox(
            width: 104,
            child: Text('${row.done} / ${row.total} LESSONS',
                style: oswald(size: 13, weight: FontWeight.w500, spacing: 0.6, color: AppColors.ink2)),
          ),
          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(row.score == null ? '—' : '${row.score}',
                  style: oswald(size: 24, weight: FontWeight.w700, color: AppColors.ink).merge(kTabular)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lessonBlocks() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          for (var i = 0; i < row.total; i++) ...[
            Expanded(
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: i < row.done ? acc.base : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i != row.total - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
