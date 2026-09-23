import 'models.dart';

/// Mock data mirrors the design prototype + ml/data/raw sample data (SRS §6.6).
/// Replaced by Firebase + /ml/estimate + behaviorFlags in later P4/P1/P2 tasks.
const kUsers = <String, OperatorUser>{
  'arjun': OperatorUser(
    username: 'arjun',
    name: 'Arjun Kumar',
    first: 'Arjun',
    initial: 'A',
    opId: 'OP1001',
    vertical: Vertical.construction,
    machineId: 'EXC004',
    machine: 'Cat 320 Excavator · EXC004',
    site: 'SITE01 · Metro depot',
    siteShort: 'the metro depot',
    source: 'Phone sensors (no telematics)',
    skill: 'Intermediate',
    gps: '12.9698, 77.7500',
    session: 'S000214',
    supervisor: 'site manager',
    passport: [
      PassportEntry(title: 'Pre-start walkaround', date: '12 Sep', score: 88),
      PassportEntry(title: 'Swing radius awareness', date: '4 Sep', score: 81),
    ],
    flag: 'Auto-assigned after a harsh-throttle flag on EXC004, 22 Sep.',
    voice: [
      'Ground crew walking behind the swing radius near the utility corridor.',
      'Soft soil at the trench edge. Possible cave-in risk.',
      'Hydraulic whine when lifting a full bucket.',
    ],
  ),
  'bala': OperatorUser(
    username: 'bala',
    name: 'Bala Murugan',
    first: 'Bala',
    initial: 'B',
    opId: 'OP2007',
    vertical: Vertical.mining,
    machineId: 'HT012',
    machine: 'Cat 777 Haul Truck · HT012',
    site: 'SITE03 · North pit',
    siteShort: 'the north pit',
    source: 'Product Link telematics',
    skill: 'Expert',
    gps: '11.5362, 79.4853',
    session: 'S001873',
    supervisor: 'dispatcher',
    passport: [
      PassportEntry(title: 'Haul-road procedures', date: '15 Sep', score: 93),
      PassportEntry(title: 'Fatigue management', date: '2 Sep', score: 90),
    ],
    flag: 'Auto-assigned after a harsh loaded-turn flag on HT012, 22 Sep.',
    voice: [
      'Rough patch on ramp R2 near km 1.4.',
      'Light vehicle parked in my blind spot at the crusher.',
      'Brakes feel soft on the loaded descent.',
    ],
  ),
};

const kTasks = <Vertical, List<OperatorTask>>{
  Vertical.construction: [
    OperatorTask(id: 'T001', type: 'Earth Excavation', location: 'Zone A · North cut', weather: 'Sunny', age: 2, est: 60, eta: 57),
    OperatorTask(id: 'T002', type: 'Trenching', location: 'Zone C · Utility corridor', weather: 'Rainy', age: 4, est: 45, eta: 51),
    OperatorTask(id: 'T003', type: 'Material Loading', location: 'Stockpile 2', weather: 'Cloudy', age: 3, est: 30, eta: 41),
    OperatorTask(id: 'T004', type: 'Grading', location: 'Zone B · Pad 4', weather: 'Sunny', age: 5, est: 35, eta: 33),
    OperatorTask(id: 'T005', type: 'Demolition', location: 'Block D · East wall', weather: 'Windy', age: 6, est: 90, eta: 104),
  ],
  Vertical.mining: [
    OperatorTask(id: 'M001', type: 'Overburden Removal', location: 'Pit 3 · Bench 410', weather: 'Dusty', age: 7, est: 120, eta: 127),
    OperatorTask(id: 'M002', type: 'Ore Loading', location: 'Shovel SH02 · Face 7', weather: 'Sunny', age: 7, est: 60, eta: 56),
    OperatorTask(id: 'M003', type: 'Load-Haul-Dump', location: 'Haul road R2 to crusher', weather: 'Sunny', age: 7, est: 45, eta: 43),
    OperatorTask(id: 'M004', type: 'Haul Road Maintenance', location: 'Ramp R2 · km 1.4', weather: 'Windy', age: 7, est: 50, eta: 53),
    OperatorTask(id: 'M005', type: 'Bench Drilling', location: 'Bench 395 · Pattern 12', weather: 'Dusty', age: 7, est: 75, eta: 79),
  ],
};

const kLessons = <Lesson>[
  Lesson(
    id: 'throttle',
    title: 'Throttle control',
    object: 'Water bottle',
    control: 'Throttle',
    auto: true,
    steps: [
      'Hold the bottle upright where the camera can see it.',
      'Tilt it forward slowly to raise the throttle.',
      'Bring it back upright to return to idle.',
      'Tilt forward, then ease back without a jerk.',
    ],
  ),
  Lesson(
    id: 'steering',
    title: 'Steering basics',
    object: 'Computer mouse',
    control: 'Steering',
    auto: false,
    steps: [
      'Place the mouse flat where the camera can see it.',
      'Turn it left to steer left.',
      'Turn it right to steer right.',
      'Center it and hold for two seconds.',
    ],
  ),
];
