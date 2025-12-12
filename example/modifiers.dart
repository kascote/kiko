import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

Future<void> main() async {
  await Application(
    title: 'Text Modifiers Example',
    onCleanup: (terminal) async {
      stderr.writeln('layoutCache ${layoutCacheStats()}');
    },
  ).runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: evt.KeyEvent(code: evt.KeyCode(char: 'q'))) => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) => draw(frame),
  );
}

void draw(Frame frame) {
  final vertical = Layout.vertical(const [ConstraintLength(1), ConstraintMin(0)]);
  final [textArea, mainArea] = vertical.areas(frame.area);

  frame.renderWidget(
    Text.raw(
      'Note: Not all terminals support all modifiers',
      style: const Style(fg: Color.red, addModifier: Modifier.bold),
    ),
    textArea,
  );

  final layout =
      Layout.vertical(
            List.generate(50, (_) => const ConstraintLength(1)),
          )
          .split(mainArea)
          .map(
            (area) => Layout.horizontal(
              List.generate(5, (_) => const ConstraintPercent(20)),
            ).split(area),
          )
          .expand((x) => x)
          .toList();

  final colors = [
    Color.black,
    Color.darkGray,
    Color.gray,
    Color.white,
    Color.red,
  ];

  var index = 0;
  for (final bg in colors) {
    for (final fg in colors) {
      for (final modifier in Modifier.list.entries) {
        final modifierName = modifier.key;
        final padding = ' ' * (12 - modifierName.length);
        final text = Text.raw(
          '$modifierName$padding',
          style: Style(
            fg: fg,
            bg: bg,
            addModifier: modifier.value,
          ),
        );
        frame.renderWidget(text, layout[index]);
        index++;
      }
    }
  }
}
