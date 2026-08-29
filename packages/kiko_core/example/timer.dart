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

  /// The generation of the running tick chain. Each start bumps it, and a
  /// tick carrying an older key is dropped instead of re-armed, so stopping
  /// and starting within one second never runs two chains at once.
  final int chain;

  const AppModel({this.seconds = 0, this.running = false, this.counter = 0, this.chain = 0});

  AppModel copyWith({int? seconds, bool? running, int? counter, int? chain}) => AppModel(
    seconds: seconds ?? this.seconds,
    running: running ?? this.running,
    counter: counter ?? this.counter,
    chain: chain ?? this.chain,
  );
}

/// The id the timer's ticks are addressed to. No widget claims it, so the
/// app's own update handles them.
const _timerId = 'timer';

/// One second, re-armed from each tick while the timer runs.
Cmd _armTick(AppModel model) => Tick(const Duration(seconds: 1), id: _timerId, key: model.chain);

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════
(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  return switch (msg) {
    // Quit on 'q'
    KeyMsg(key: 'q') => (model, const Quit()),

    // Space toggles the timer: starting arms a tick under a fresh generation;
    // stopping just stops re-arming.
    KeyMsg(key: 'space') when model.running => (model.copyWith(running: false), null),
    KeyMsg(key: 'space') => _start(model),

    // Reset timer on 'r'
    KeyMsg(key: 'r') => (model.copyWith(seconds: 0, running: false), null),

    // Arrow keys control counter (works while timer runs)
    KeyMsg(key: 'up') => (model.copyWith(counter: model.counter + 1), null),
    KeyMsg(key: 'down') => (model.copyWith(counter: model.counter - 1), null),

    // A tick of the current chain advances the timer and re-arms itself. One
    // from a chain that was stopped, or restarted since, is consumed and
    // dropped.
    TickMsg(id: _timerId, :final key) when model.running && key == model.chain => (
      model.copyWith(seconds: model.seconds + 1),
      _armTick(model),
    ),
    TickMsg() => (model, null),

    _ => (model, null),
  };
}

(AppModel, Cmd?) _start(AppModel model) {
  final started = model.copyWith(running: true, chain: model.chain + 1);
  return (started, _armTick(started));
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
