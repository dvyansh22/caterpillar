/// Data models for AR training modules and lessons.
///
/// Per DESIGN.md §18 — everyday-object mapping + field repair.
library;

/// Difficulty levels for training modules.
enum ModuleDifficulty { beginner, intermediate, advanced }

/// Status of a training module for the current user.
enum ModuleStatus { locked, available, inProgress, completed }

/// A single AR training module (e.g., "Steering Control" mapped to a mouse).
class TrainingModule {
  const TrainingModule({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.difficulty,
    required this.steps,
    this.status = ModuleStatus.available,
    this.completedSteps = 0,
    this.bestScore = 0,
    this.everydayObject,
    this.machineControl,
    this.verticals = const ['construction', 'mining'],
  });

  final String id;
  final String title;
  final String description;
  final String iconName;
  final ModuleDifficulty difficulty;
  final List<LessonStep> steps;
  final ModuleStatus status;
  final int completedSteps;
  final double bestScore;

  /// The real-world everyday object used in the demo (e.g., "mouse").
  final String? everydayObject;

  /// The machine control it maps to (e.g., "steering").
  final String? machineControl;

  /// Which verticals this module applies to.
  final List<String> verticals;

  double get progressPercent =>
      steps.isEmpty ? 0 : completedSteps / steps.length;

  TrainingModule copyWith({
    ModuleStatus? status,
    int? completedSteps,
    double? bestScore,
  }) {
    return TrainingModule(
      id: id,
      title: title,
      description: description,
      iconName: iconName,
      difficulty: difficulty,
      steps: steps,
      status: status ?? this.status,
      completedSteps: completedSteps ?? this.completedSteps,
      bestScore: bestScore ?? this.bestScore,
      everydayObject: everydayObject,
      machineControl: machineControl,
      verticals: verticals,
    );
  }
}

/// A single step within a training lesson.
class LessonStep {
  const LessonStep({
    required this.index,
    required this.instruction,
    required this.hint,
    this.expectedAction,
    this.durationSeconds = 30,
  });

  final int index;

  /// What the trainee should do (shown on screen).
  final String instruction;

  /// A hint shown if the trainee is stuck.
  final String hint;

  /// The action the AR engine should detect (e.g., "rotate_left").
  final String? expectedAction;

  /// Time limit for this step.
  final int durationSeconds;
}

/// Pre-built training modules per DESIGN.md §18.
abstract final class DefaultModules {
  static const steeringControl = TrainingModule(
    id: 'steering_control',
    title: 'Gear & Boom Control',
    description: 'Grip the red-capped controller and move it forward/back to '
        'raise or lower the crane boom, and left/right to swing the cab. The '
        'app tracks the red cap in real time.',
    iconName: 'sports_esports',
    difficulty: ModuleDifficulty.beginner,
    everydayObject: 'Red Cap',
    machineControl: 'Crane Boom & Swing',
    steps: [
      LessonStep(
        index: 0,
        instruction: 'Point your camera at the mouse on the desk.',
        hint: 'Make sure the mouse is clearly visible with good lighting.',
      ),
      LessonStep(
        index: 1,
        instruction: 'Move the mouse to the LEFT to steer left.',
        hint: 'Slide the mouse slowly to the left side.',
        expectedAction: 'steer_left',
      ),
      LessonStep(
        index: 2,
        instruction: 'Move the mouse to the RIGHT to steer right.',
        hint: 'Slide the mouse slowly to the right side.',
        expectedAction: 'steer_right',
      ),
      LessonStep(
        index: 3,
        instruction: 'Make a smooth LEFT-RIGHT-CENTER sequence.',
        hint: 'Move smoothly: left, right, then back to center.',
        expectedAction: 'steer_sequence',
        durationSeconds: 45,
      ),
      LessonStep(
        index: 4,
        instruction: 'Complete the timed steering challenge!',
        hint: 'Follow the on-screen arrows as fast as you can.',
        expectedAction: 'steer_challenge',
        durationSeconds: 60,
      ),
    ],
  );

  static const throttleControl = TrainingModule(
    id: 'throttle_control',
    title: 'Throttle Control',
    description: 'Learn throttle/thrust control by mapping a water bottle to '
        'the throttle lever. Raise to accelerate, lower to decelerate.',
    iconName: 'speed',
    difficulty: ModuleDifficulty.beginner,
    everydayObject: 'Water Bottle',
    machineControl: 'Throttle / Thrust Control',
    steps: [
      LessonStep(
        index: 0,
        instruction: 'Point your camera at the water bottle.',
        hint: 'Place the bottle upright on a flat surface.',
      ),
      LessonStep(
        index: 1,
        instruction: 'RAISE the bottle to increase throttle.',
        hint: 'Lift the bottle upward smoothly.',
        expectedAction: 'throttle_up',
      ),
      LessonStep(
        index: 2,
        instruction: 'LOWER the bottle to decrease throttle.',
        hint: 'Bring the bottle back down slowly.',
        expectedAction: 'throttle_down',
      ),
      LessonStep(
        index: 3,
        instruction: 'Hold throttle steady at 50% for 5 seconds.',
        hint: 'Keep the bottle at mid-height, nice and stable.',
        expectedAction: 'throttle_hold',
        durationSeconds: 15,
      ),
      LessonStep(
        index: 4,
        instruction: 'Complete the throttle ramp challenge!',
        hint: 'Smoothly go from 0% to 100% and back down.',
        expectedAction: 'throttle_ramp',
        durationSeconds: 45,
      ),
    ],
  );

  static const bucketControl = TrainingModule(
    id: 'bucket_control',
    title: 'Bucket / Attachment',
    description: 'Practice operating the bucket or front attachment using a '
        'book as a proxy. Tilt to scoop, level to carry.',
    iconName: 'construction',
    difficulty: ModuleDifficulty.intermediate,
    everydayObject: 'Book',
    machineControl: 'Bucket / Front Attachment',
    steps: [
      LessonStep(
        index: 0,
        instruction: 'Point your camera at a book on the desk.',
        hint: 'Place the book flat where it can be clearly seen.',
      ),
      LessonStep(
        index: 1,
        instruction: 'TILT the book forward to scoop.',
        hint: 'Angle the front edge of the book downward.',
        expectedAction: 'bucket_scoop',
      ),
      LessonStep(
        index: 2,
        instruction: 'LEVEL the book to carry the load.',
        hint: 'Hold the book flat and level.',
        expectedAction: 'bucket_level',
      ),
      LessonStep(
        index: 3,
        instruction: 'TILT the book backward to dump.',
        hint: 'Rotate the book to dump the imaginary load.',
        expectedAction: 'bucket_dump',
      ),
      LessonStep(
        index: 4,
        instruction: 'Complete a full scoop-carry-dump cycle!',
        hint: 'Scoop, level, carry forward, then dump.',
        expectedAction: 'bucket_cycle',
        durationSeconds: 45,
      ),
    ],
  );

  static const leverControl = TrainingModule(
    id: 'lever_control',
    title: 'Hydraulic Lever',
    description: 'Operate a proportional machine lever by sliding the '
        'blue-knob controller along its channel. Slide to the top, middle, and '
        'bottom stops — the app reads the lever position in real time.',
    iconName: 'tune',
    difficulty: ModuleDifficulty.intermediate,
    everydayObject: 'Blue Knob',
    machineControl: 'Hydraulic Boom Lever',
    steps: [
      LessonStep(
        index: 0,
        instruction: 'Slide the adapter to the TOP stop.',
        hint: 'Push the adapter all the way up the channel.',
        expectedAction: 'lever_top',
      ),
      LessonStep(
        index: 1,
        instruction: 'Slide down to the MIDDLE stop.',
        hint: 'Hold the adapter steady at the mid point.',
        expectedAction: 'lever_mid',
      ),
      LessonStep(
        index: 2,
        instruction: 'Slide to the BOTTOM stop.',
        hint: 'Bring the adapter all the way down.',
        expectedAction: 'lever_bottom',
      ),
      LessonStep(
        index: 3,
        instruction: 'Raise it back to the TOP.',
        hint: 'Return the lever to full.',
        expectedAction: 'lever_top',
      ),
    ],
  );

  static const fieldRepair = TrainingModule(
    id: 'field_repair',
    title: 'Field Repair Basics',
    description: 'Learn to use the AR repair view. Identify fault-highlighted '
        'components and follow animated repair steps.',
    iconName: 'build',
    difficulty: ModuleDifficulty.advanced,
    everydayObject: null,
    machineControl: null,
    steps: [
      LessonStep(
        index: 0,
        instruction: 'Open the AR repair view on a machine.',
        hint: 'Point your camera at the machine or scan a QR code.',
      ),
      LessonStep(
        index: 1,
        instruction: 'Identify the fault-highlighted component.',
        hint: 'Look for the red/orange highlighted part in the AR view.',
        expectedAction: 'identify_fault',
      ),
      LessonStep(
        index: 2,
        instruction: 'Follow the animated disassembly steps.',
        hint: 'Watch the animation and note the tool sequence.',
        expectedAction: 'follow_animation',
        durationSeconds: 60,
      ),
      LessonStep(
        index: 3,
        instruction: 'Check the torque spec and reassemble.',
        hint: 'Confirm the torque value shown in the overlay.',
        expectedAction: 'check_torque',
      ),
      LessonStep(
        index: 4,
        instruction: 'Mark the repair as complete.',
        hint: 'Tap the complete button to finish.',
        expectedAction: 'complete_repair',
      ),
    ],
  );

  static const combinedControl = TrainingModule(
    id: 'combined_control',
    title: 'Operator Console Drill',
    description: 'Run a full operator console in landscape: the app guides you '
        'through the RED gear and the BLUE lever one by one, tracking both at '
        'once. Hold the phone sideways with both controllers in view.',
    iconName: 'sports_esports',
    difficulty: ModuleDifficulty.advanced,
    everydayObject: 'Red Gear + Blue Lever',
    machineControl: 'Full Machine Console',
    steps: [
      LessonStep(index: 0, instruction: 'Red gear — forward', hint: 'Move the red gear away from you.'),
      LessonStep(index: 1, instruction: 'Red gear — back', hint: 'Pull the red gear toward you.'),
      LessonStep(index: 2, instruction: 'Red gear — left', hint: 'Move the red gear left.'),
      LessonStep(index: 3, instruction: 'Red gear — right', hint: 'Move the red gear right.'),
      LessonStep(index: 4, instruction: 'Blue lever — up', hint: 'Slide the blue lever up.'),
      LessonStep(index: 5, instruction: 'Blue lever — down', hint: 'Slide the blue lever down.'),
    ],
  );

  static const List<TrainingModule> all = [
    combinedControl,
    steeringControl,
    leverControl,
  ];
}
