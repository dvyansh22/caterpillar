import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen-flow / navigation state, mirroring the design prototype's view model.
enum AppPhase { login, gate, welcome, app }

enum AppTab { task, learn, profile, sos }

enum TaskView { list, detail, active }

class NavState {
  const NavState({
    this.phase = AppPhase.login,
    this.tab = AppTab.task,
    this.prevTab = AppTab.task,
    this.taskView = TaskView.list,
    this.selId,
    this.lessonId,
  });

  final AppPhase phase;
  final AppTab tab;
  final AppTab prevTab;
  final TaskView taskView;
  final String? selId;
  final String? lessonId;

  NavState copyWith({
    AppPhase? phase,
    AppTab? tab,
    AppTab? prevTab,
    TaskView? taskView,
    Object? selId = _s,
    Object? lessonId = _s,
  }) {
    return NavState(
      phase: phase ?? this.phase,
      tab: tab ?? this.tab,
      prevTab: prevTab ?? this.prevTab,
      taskView: taskView ?? this.taskView,
      selId: selId == _s ? this.selId : selId as String?,
      lessonId: lessonId == _s ? this.lessonId : lessonId as String?,
    );
  }

  static const _s = Object();
}

class NavController extends Notifier<NavState> {
  @override
  NavState build() => const NavState();

  void toGate() => state = state.copyWith(phase: AppPhase.gate);
  void toWelcome() => state = state.copyWith(phase: AppPhase.welcome);
  void toApp() => state = state.copyWith(phase: AppPhase.app);

  void reset() => state = const NavState();

  /// Tapping Task returns to the running task if there is one, else the list.
  void goTask({required bool hasActive}) => state = state.copyWith(
        tab: AppTab.task,
        taskView: hasActive ? TaskView.active : TaskView.list,
      );

  void goLearn() => state = state.copyWith(tab: AppTab.learn, lessonId: null);
  void goProfile() => state = state.copyWith(tab: AppTab.profile);

  void openSos() => state = state.copyWith(
        prevTab: state.tab == AppTab.sos ? state.prevTab : state.tab,
        tab: AppTab.sos,
      );
  void closeSos() => state = state.copyWith(tab: state.prevTab);

  void openTaskDetail(String id) =>
      state = state.copyWith(tab: AppTab.task, taskView: TaskView.detail, selId: id);
  void openActiveTask() => state = state.copyWith(tab: AppTab.task, taskView: TaskView.active);
  void backToList() => state = state.copyWith(taskView: TaskView.list);

  void openLesson(String id) => state = state.copyWith(tab: AppTab.learn, lessonId: id);
  void closeLesson() => state = state.copyWith(lessonId: null);
}

final navProvider = NotifierProvider<NavController, NavState>(NavController.new);
