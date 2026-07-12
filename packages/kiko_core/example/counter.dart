import 'dart:io';

import 'package:kiko/kiko.dart';

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════
//
// NOTE: Kiko models are mutable by default (Bubble Tea style). Immutable + `copyWith`
// is fine for a standalone value model like this (one int) — and it stops there. The
// moment your model holds widget models (TextInput, Table, …), those are mutable and you
// address their events by stable reference, so the app model goes mutable too. Don't
// read this as "immutable scales to a real UI" — it doesn't.
class CounterModel {
  final int count;

  const CounterModel({this.count = 0});

  CounterModel copyWith({int? count}) => CounterModel(count: count ?? this.count);
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════
(CounterModel, Cmd?) counterUpdate(CounterModel model, Msg msg, UpdateContext _) {
  return switch (msg) {
    KeyMsg(key: 'q') => (model, const Quit()),
    KeyMsg(key: 'up') => (model.copyWith(count: model.count + 1), null),
    KeyMsg(key: 'down') => (model.copyWith(count: model.count - 1), null),
    _ => (model, null),
  };
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════
void counterView(CounterModel model, Frame frame) {
  final ui = Container(
    border: BorderType.plain,
    topTitles: [Line('Counter (↑/↓ to change, q to quit)')],
    child: Center(child: Line('Count: ${model.count}')),
  );

  frame.render(ui);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════
Future<void> main() async {
  exit(
    await Application(title: 'Counter MVU').run(
      init: const CounterModel(),
      update: counterUpdate,
      view: counterView,
    ),
  );
}
