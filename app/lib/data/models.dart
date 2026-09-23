import '../core/tokens.dart';

enum Vertical { construction, mining }

extension VerticalX on Vertical {
  String get label => this == Vertical.construction ? 'Construction' : 'Mining';
  AccentPalette get accent =>
      this == Vertical.construction ? AccentPalette.construction : AccentPalette.mining;
}

class PassportEntry {
  const PassportEntry({required this.title, required this.date, required this.score});
  final String title;
  final String date;
  final int score;
}

class OperatorUser {
  const OperatorUser({
    required this.username,
    required this.name,
    required this.first,
    required this.initial,
    required this.opId,
    required this.vertical,
    required this.machineId,
    required this.machine,
    required this.site,
    required this.siteShort,
    required this.source,
    required this.skill,
    required this.gps,
    required this.session,
    required this.supervisor,
    required this.passport,
    required this.flag,
    required this.voice,
  });

  final String username;
  final String name;
  final String first;
  final String initial;
  final String opId;
  final Vertical vertical;
  final String machineId;
  final String machine;
  final String site;
  final String siteShort;
  final String source;
  final String skill;
  final String gps;
  final String session;
  final String supervisor;
  final List<PassportEntry> passport;
  final String flag;
  final List<String> voice;

  String get verticalLabel => vertical.label;
  AccentPalette get accent => vertical.accent;
}

class OperatorTask {
  const OperatorTask({
    required this.id,
    required this.type,
    required this.location,
    required this.weather,
    required this.age,
    required this.est,
    required this.eta,
  });

  final String id;
  final String type;
  final String location;
  final String weather;
  final int age; // machine age (yrs)
  final int est; // planner baseline (min)
  final int eta; // ML-predicted (min)
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.object,
    required this.control,
    required this.auto,
    required this.steps,
  });

  final String id;
  final String title;
  final String object;
  final String control;
  final bool auto;
  final List<String> steps;

  int get score => id == 'throttle' ? 92 : 88;
}

class VoiceLog {
  const VoiceLog({required this.text, required this.time, required this.sync});
  final String text;
  final String time;
  final String sync;
}
