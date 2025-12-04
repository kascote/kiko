import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

Future<void> main() async {
  await Application(
    title: 'Text Modifiers Example (Declarative)',
    onCleanup: (terminal) async {
      stderr.writeln('layoutCache ${layoutCacheStats()}');
    },
  ).run(
    render: draw,
    onEvent: (event) {
      if (event is evt.KeyEvent && event.code.char == 'q') return 0;
      return null;
    },
  );
}

void draw(Frame frame) {
  final ui = Column(
    children: [
      Fixed(
        1,
        child: Text.raw(
          'Note: Not all terminals support all modifiers',
          style: const Style(fg: Color.red, addModifier: Modifier.bold),
        ),
      ),
      Expanded(child: ModifiersGrid()),
    ],
  );

  frame.renderWidget(ui, frame.area);
}

final List<Color> _colors = [
  Color.black,
  Color.darkGray,
  Color.gray,
  Color.white,
  Color.red,
];

final List<MapEntry<String, Modifier>> _modifiers = Modifier.list.entries.toList();

/// Grid displaying all modifiers with color combinations.
/// 50 rows × 5 columns. Each color combo takes 2 rows (10 modifiers / 5 per row).
class ModifiersGrid implements Widget {
  @override
  void render(Rect area, Frame frame) {
    final rowChildren = <LayoutChild>[];

    for (final bg in _colors) {
      for (final fg in _colors) {
        // First row: modifiers 0-4
        final row1 = <LayoutChild>[];
        for (var i = 0; i < 5; i++) {
          row1.add(
            Percent(
              20,
              child: _ModifierCell(fg: fg, bg: bg, modifier: _modifiers[i]),
            ),
          );
        }
        rowChildren.add(Fixed(1, child: Row(children: row1)));

        // Second row: modifiers 5-9
        final row2 = <LayoutChild>[];
        for (var i = 5; i < 10; i++) {
          row2.add(
            Percent(
              20,
              child: _ModifierCell(fg: fg, bg: bg, modifier: _modifiers[i]),
            ),
          );
        }
        rowChildren.add(Fixed(1, child: Row(children: row2)));
      }
    }

    Column(children: rowChildren).render(area, frame);
  }
}

class _ModifierCell implements Widget {
  final Color fg;
  final Color bg;
  final MapEntry<String, Modifier> modifier;

  const _ModifierCell({
    required this.fg,
    required this.bg,
    required this.modifier,
  });

  @override
  void render(Rect area, Frame frame) {
    final modifierName = modifier.key;
    final padding = ' ' * (12 - modifierName.length);
    Text.raw(
      '$modifierName$padding',
      style: Style(fg: fg, bg: bg, addModifier: modifier.value),
    ).render(area, frame);
  }
}
