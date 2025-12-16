import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════
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
(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  return switch (msg) {
    // Quit on 'q'
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(char: 'q'))) => (model, const Quit()),

    // Space toggles timer
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(char: ' '))) =>
      model.running
          ? (model.copyWith(running: false), const StopTick())
          : (model.copyWith(running: true), const Tick(Duration(seconds: 1))),

    // Reset timer on 'r'
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(char: 'r'))) => (
      model.copyWith(seconds: 0, running: false),
      const StopTick(),
    ),

    // Arrow keys control counter (works while timer runs)
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(name: evt.KeyCodeName.up))) => (
      model.copyWith(counter: model.counter + 1),
      null,
    ),
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(name: evt.KeyCodeName.down))) => (
      model.copyWith(counter: model.counter - 1),
      null,
    ),

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
    children: [
      // Timer pane (left)
      Expanded(
        child: Block(
          borders: Borders.all,
          child: Column(
            children: [
              Expanded(child: Text.raw(time, alignment: Alignment.center)),
              Fixed(
                1,
                child: Text.raw(
                  status,
                  alignment: Alignment.center,
                  style: Style(fg: model.running ? Color.green : Color.red),
                ),
              ),
            ],
          ),
        ).titleTop(Line('Timer (space/r)')),
      ),
      // Counter pane (right)
      Expanded(
        child: Block(
          borders: Borders.all,
          child: Text.raw('Count: ${model.counter}', alignment: Alignment.center),
        ).titleTop(Line('Counter (↑/↓)')),
      ),
    ],
  );

  final outer = Block(borders: Borders.all, child: ui).titleTop(Line('q=quit'));
  frame.renderWidget(outer, frame.area);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════
void main() async {
  await Application(title: 'Timer + Counter MVU').run(
    init: const AppModel(),
    update: appUpdate,
    view: appView,
  );
}
