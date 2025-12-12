import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════
class CounterModel {
  final int count;

  const CounterModel({this.count = 0});

  CounterModel copyWith({int? count}) => CounterModel(count: count ?? this.count);
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════
(CounterModel, Cmd?) counterUpdate(CounterModel model, Msg msg) {
  return switch (msg) {
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(char: 'q'))) => (model, const Quit()),
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(name: evt.KeyCodeName.up))) => (
      model.copyWith(count: model.count + 1),
      null,
    ),
    KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(name: evt.KeyCodeName.down))) => (
      model.copyWith(count: model.count - 1),
      null,
    ),
    _ => (model, null),
  };
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════
void counterView(CounterModel model, Frame frame) {
  final block = Block(
    borders: Borders.all,
    child: Text.raw('Count: ${model.count}', alignment: Alignment.center),
  ).titleTop(Line('Counter (↑/↓ to change, q to quit)'));

  frame.renderWidget(block, frame.area);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════
void main() async {
  await Application(title: 'Counter MVU').run(
    init: const CounterModel(),
    update: counterUpdate,
    view: counterView,
  );
}
