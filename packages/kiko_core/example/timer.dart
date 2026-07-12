import 'dart:io';

import 'package:kiko/kiko.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════
//
// NOTE: Kiko models are mutable by default (Bubble Tea style). Immutable + `copyWith`
// is fine for a standalone value model like this — and it stops there. The moment your
// model holds widget models (TextInput, Table, …), those are mutable and you address
// their events by stable reference, so the app model goes mutable too. Don't read this
// as "immutable scales to a real UI" — it doesn't.
class AppModel {
  final int seconds;
  final bool running;
  final int counter;

  const AppModel({this.seconds = 0, this.running = false, this.counter = 0});

  AppModel copyWith({int? seconds, bool? running, int? counter}) => AppModel(
    seconds: seconds ?? this.seconds,
    running: running ?? this.running,
    counter: counter ?? this.counter,
  );
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════
(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  return switch (msg) {
    // Quit on 'q'
    KeyMsg(key: 'q') => (model, const Quit()),

    // Space toggles timer
    KeyMsg(key: 'space') =>
      model.running
          ? (model.copyWith(running: false), const StopTick())
          : (model.copyWith(running: true), const Tick(Duration(seconds: 1))),

    // Reset timer on 'r'
    KeyMsg(key: 'r') => (model.copyWith(seconds: 0, running: false), const StopTick()),

    // Arrow keys control counter (works while timer runs)
    KeyMsg(key: 'up') => (model.copyWith(counter: model.counter + 1), null),
    KeyMsg(key: 'down') => (model.copyWith(counter: model.counter - 1), null),

    // Tick increments timer
    TickMsg() => (model.copyWith(seconds: model.seconds + 1), null),

    _ => (model, null),
  };
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════
void appView(AppModel model, Frame frame) {
  final minutes = model.seconds ~/ 60;
  final secs = model.seconds % 60;
  final time = '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  final status = model.running ? 'RUNNING' : 'STOPPED';

  final ui = Row(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      // Timer pane (left)
      Expanded(
        child: Container(
          border: BorderType.plain,
          topTitles: [Line('Timer (space/r)')],
          child: Column(
            children: [
              Expanded(child: Center(child: Line(time))),
              Center(
                child: Line(
                  status,
                  style: Style(fg: model.running ? Color.green : Color.red),
                ),
              ),
            ],
          ),
        ),
      ),
      // Counter pane (right)
      Expanded(
        child: Container(
          border: BorderType.plain,
          topTitles: [Line('Counter (↑/↓)')],
          child: Center(child: Line('Count: ${model.counter}')),
        ),
      ),
    ],
  );

  final outer = Container(border: BorderType.plain, topTitles: [Line('q=quit')], child: ui);
  frame.render(outer);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════
Future<void> main() async {
  exit(
    await Application(title: 'Timer + Counter MVU').run(
      init: const AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
