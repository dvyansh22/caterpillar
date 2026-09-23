import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/nav.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../services/ml_client/ml_providers.dart';

// ---------------------------------------------------------------------------
// Owner / fleet dashboard (web). Deliberately minimal — matches the app theme.
// Mock data for now; wire to Firestore (machines/incidents/tasks/training) later.
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

enum MStatus { inUse, idle, offline }

class Machine {
  const Machine(this.id, this.type, this.operator, this.status, this.phoneFed, this.alerts);
  final String id, type, operator;
  final MStatus status;
  final bool phoneFed; // true = phone sensors (no telematics), false = telematics
  final int alerts;
}

class IncidentRow {
  const IncidentRow(this.severity, this.text, this.machine, this.time);
  final String severity; // safety | anomaly | observation
  final String text, machine, time;
}

class TrainingRow {
  const TrainingRow(this.operator, this.done, this.total, this.score);
  final String operator;
  final int done, total;
  final int? score;
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
    Machine('EXC004', 'Cat 320 Excavator', 'Arjun Kumar', MStatus.inUse, true, 2),
    Machine('LDR003', 'Cat 950 Loader', 'Ravi Kumar', MStatus.inUse, true, 1),
    Machine('DZR004', 'Cat D6 Dozer', 'Sam Thomas', MStatus.inUse, true, 0),
    Machine('GRD002', 'Cat 140 Grader', 'Priya S', MStatus.idle, false, 0),
    Machine('TRK006', 'Cat 745 Truck', 'Amit P', MStatus.idle, false, 0),
    Machine('BHL005', 'Cat 420 Backhoe', 'Neha R', MStatus.inUse, true, 0),
    Machine('SKD007', 'Cat 262 Skid Steer', 'Vikram J', MStatus.offline, true, 0),
    Machine('PVR008', 'Cat AP500 Paver', 'Lena M', MStatus.offline, false, 0),
  ],
  [
    IncidentRow('safety', 'Ground crew behind swing radius', 'EXC004', '14:02'),
    IncidentRow('observation', 'Soft soil at trench edge, cave-in risk', 'EXC004', '13:20'),
    IncidentRow('safety', 'Unfastened seatbelt during operation', 'LDR003', '11:47'),
    IncidentRow('anomaly', 'Excessive idling flagged', 'DZR004', '10:15'),
    IncidentRow('observation', 'Hydraulic whine on a full bucket', 'EXC004', '09:05'),
  ],
  [28, 22, 31, 19, 24, 15, 22],
  [
    TrainingRow('Arjun Kumar', 2, 3, 92),
    TrainingRow('Ravi Kumar', 2, 3, 78),
    TrainingRow('Sam Thomas', 3, 3, 88),
    TrainingRow('Neha R', 1, 3, 74),
  ],
);

const _mining = _Site(
  'SITE03 · North pit',
  [
    Machine('HT012', 'Cat 777 Haul Truck', 'Bala Murugan', MStatus.inUse, false, 1),
    Machine('HT009', 'Cat 777 Haul Truck', 'Deepa N', MStatus.inUse, true, 1),
    Machine('SH02', 'Cat 6015 Shovel', 'Karan V', MStatus.inUse, false, 0),
    Machine('DR07', 'Cat MD6250 Drill', 'Manoj T', MStatus.inUse, false, 0),
    Machine('LV03', 'Light Vehicle', 'Rohit S', MStatus.idle, true, 0),
    Machine('DZ08', 'Cat D9 Dozer', 'Sana K', MStatus.idle, true, 0),
    Machine('HT015', 'Cat 777 Haul Truck', 'Arjun P', MStatus.offline, true, 0),
    Machine('GR04', 'Cat 16 Grader', 'Iqbal M', MStatus.offline, false, 0),
  ],
  [
    IncidentRow('safety', 'Unfastened seatbelt with fatigue', 'HT012', '14:10'),
    IncidentRow('observation', 'Rough patch on ramp R2, km 1.4', 'HT012', '12:55'),
    IncidentRow('safety', 'Light vehicle in blind spot at crusher', 'HT009', '11:30'),
    IncidentRow('anomaly', 'Harsh loaded turn flagged', 'HT012', '10:40'),
    IncidentRow('observation', 'Brakes soft on a loaded descent', 'HT009', '09:15'),
  ],
  [18, 24, 20, 27, 22, 16, 21],
  [
    TrainingRow('Bala Murugan', 2, 2, 93),
    TrainingRow('Karan V', 1, 2, 85),
    TrainingRow('Deepa N', 2, 2, 90),
    TrainingRow('Rohit S', 0, 2, null),
  ],
);

/// Live dashboard data: fleet + idle from the model backend (`/ml/fleet`),
/// incidents + training from Firestore. Falls back to the seed site for any
/// piece the backend/Firestore can't provide, so the view is never blank.
final dashSiteProvider = FutureProvider.autoDispose.family<_Site, Vertical>((ref, vertical) async {
  final vs = vertical == Vertical.mining ? 'mining' : 'construction';
  final seed = vertical == Vertical.mining ? _mining : _construction;

  final repo = ref.read(dataRepositoryProvider);
  final fleet = await ref.read(mlClientProvider).getFleet(vs); // null if backend down
  // Firestore reads can be denied (e.g. dashboard opened without auth); fall back
  // to seed per-source instead of failing the whole load.
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
      : [for (final i in incidents) IncidentRow(i.severity, i.text, i.machineId, i.time)];
  final trainingRows = training.isEmpty ? seed.training : _aggregateTraining(training);

  return _Site(seed.name, machines, incidentRows, idleWeek, trainingRows);
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
      ),
  ];
}

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

    return Scaffold(
      body: Column(
        children: [
          _TopBar(vertical: vertical, tab: tab, acc: acc, live: live),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
                    child: switch (tab) {
                      DashTab.overview => _Overview(site: site, acc: acc),
                      DashTab.fleet => _FleetTable(site.machines, acc, full: true),
                      DashTab.incidents => _IncidentsList(site.incidents, acc, full: true),
                      DashTab.training => _Training(site, acc),
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.vertical, required this.tab, required this.acc, required this.live});
  final Vertical vertical;
  final DashTab tab;
  final AccentPalette acc;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tabBtn(DashTab t, String label) {
      final active = tab == t;
      return InkWell(
        onTap: () => ref.read(dashTabProvider.notifier).set(t),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: AppColors.ink)),
              const SizedBox(height: 6),
              Container(height: 2, width: 22, color: active ? acc.base : Colors.transparent),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 64,
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
            decoration: BoxDecoration(color: acc.base, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.precision_manufacturing, size: 18, color: AppColors.ink),
          ),
          const SizedBox(width: 10),
          const Text('Smart Operator · Fleet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: live ? AppColors.successBg : AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: live ? AppColors.successInk : AppColors.muted2, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(live ? 'Live' : 'Loading',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: live ? AppColors.successInk : AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          tabBtn(DashTab.overview, 'Overview'),
          tabBtn(DashTab.fleet, 'Fleet'),
          tabBtn(DashTab.incidents, 'Incidents'),
          tabBtn(DashTab.training, 'Training'),
          const Spacer(),
          _VerticalToggle(vertical: vertical, acc: acc),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(navProvider.notifier).reset(),
            icon: const Icon(Icons.logout, size: 20, color: AppColors.muted),
          ),
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
    Widget seg(Vertical v, String label) {
      final on = vertical == v;
      return InkWell(
        onTap: () => ref.read(dashVerticalProvider.notifier).set(v),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: on ? v.accent.tint : Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: AppColors.ink)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [seg(Vertical.construction, 'Construction'), seg(Vertical.mining, 'Mining')]),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.site, required this.acc});
  final _Site site;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context) {
    final active = site.machines.where((m) => m.status != MStatus.offline).length;
    final alerts = site.machines.fold<int>(0, (a, m) => a + m.alerts);
    final avgIdle = (site.idleWeek.reduce((a, b) => a + b) / site.idleWeek.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fleet overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text('Wednesday, 23 September · ${site.name}', style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        const SizedBox(height: 24),
        Row(
          children: [
            _kpi('Active machines', '$active of ${site.machines.length}'),
            const SizedBox(width: 20),
            _kpi('Safety alerts today', '$alerts', danger: alerts > 0),
            const SizedBox(width: 20),
            _kpi('Open incidents', '${site.incidents.length}'),
            const SizedBox(width: 20),
            _kpi('Avg idle time', '$avgIdle%'),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 900;
          final left = _FleetTable(site.machines, acc);
          final right = _IncidentsList(site.incidents, acc);
          if (!wide) return Column(children: [left, const SizedBox(height: 24), right]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: left),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: right),
            ],
          );
        }),
        const SizedBox(height: 24),
        _IdleChart(site.idleWeek, acc),
      ],
    );
  }

  Widget _kpi(String label, String value, {bool danger = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.4, color: AppColors.muted)),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w500, color: danger ? AppColors.danger : AppColors.ink).merge(kTabular)),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.ink)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FleetTable extends StatelessWidget {
  const _FleetTable(this.machines, this.acc, {this.full = false});
  final List<Machine> machines;
  final AccentPalette acc;
  final bool full;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Fleet status',
      child: Column(
        children: [
          for (var i = 0; i < machines.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == machines.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: _row(machines[i]),
            ),
        ],
      ),
    );
  }

  Widget _row(Machine m) {
    final (Color sBg, Color sInk, String sLabel) = switch (m.status) {
      MStatus.inUse => (acc.base, AppColors.ink, 'In use'),
      MStatus.idle => (AppColors.surface2, AppColors.muted, 'Idle'),
      MStatus.offline => (AppColors.surface2, AppColors.muted2, 'Offline'),
    };
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(m.id, style: const TextStyle(fontSize: 13, color: AppColors.ink2).merge(kMono)),
                const SizedBox(width: 8),
                Flexible(child: Text('· ${m.type}', style: const TextStyle(fontSize: 13, color: AppColors.muted), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 2),
              Text(m.operator, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
          ),
        ),
        Expanded(flex: 2, child: _chip(sLabel, sBg, sInk)),
        Expanded(
          flex: 3,
          child: _chip(m.phoneFed ? 'Phone sensors' : 'Telematics', m.phoneFed ? acc.tint : AppColors.surface2, m.phoneFed ? acc.ink : AppColors.muted),
        ),
        SizedBox(
          width: 60,
          child: Align(
            alignment: Alignment.centerRight,
            child: m.alerts > 0
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${m.alerts}', style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600)),
                  ])
                : const Text('—', style: TextStyle(fontSize: 13, color: AppColors.muted2)),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color bg, Color ink) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ink)),
        ),
      );
}

class _IncidentsList extends StatelessWidget {
  const _IncidentsList(this.incidents, this.acc, {this.full = false});
  final List<IncidentRow> incidents;
  final AccentPalette acc;
  final bool full;

  @override
  Widget build(BuildContext context) {
    Color dot(String s) => switch (s) {
          'safety' => AppColors.danger,
          'anomaly' => const Color(0xFFF9A825),
          _ => AppColors.muted2,
        };
    return _Card(
      title: 'Recent incidents & alerts',
      child: Column(
        children: [
          for (final i in incidents)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: dot(i.severity), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${i.text} · ${i.machine}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
                  ),
                  const SizedBox(width: 8),
                  Text(i.time, style: const TextStyle(fontSize: 12, color: AppColors.muted).merge(kMono)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IdleChart extends StatelessWidget {
  const _IdleChart(this.week, this.acc);
  final List<int> week;
  final AccentPalette acc;

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxV = (week.reduce((a, b) => a > b ? a : b)).clamp(1, 100);
    return _Card(
      title: 'Idle time this week',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fleet average', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < week.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${week[i]}%', style: const TextStyle(fontSize: 12, color: AppColors.muted).merge(kTabular)),
                          const SizedBox(height: 4),
                          Container(
                            height: 120 * (week[i] / maxV),
                            decoration: BoxDecoration(color: acc.base, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                          ),
                          const SizedBox(height: 8),
                          Text(days[i], style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
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

class _Training extends StatelessWidget {
  const _Training(this.site, this.acc);
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
        const Text('Training compliance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text('Team compliance $pct%', style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        const SizedBox(height: 20),
        _Card(
          title: 'Operators',
          child: Column(
            children: [
              for (var i = 0; i < site.training.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: i == site.training.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: _trainRow(site.training[i], acc),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trainRow(TrainingRow t, AccentPalette acc) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(t.operator, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
        ),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${t.done}/${t.total} lessons', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: t.total == 0 ? 0 : t.done / t.total,
                  minHeight: 6,
                  backgroundColor: AppColors.surface2,
                  valueColor: AlwaysStoppedAnimation(acc.base),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 70,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(t.score == null ? '—' : '${t.score}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.ink).merge(kTabular)),
          ),
        ),
      ],
    );
  }
}
