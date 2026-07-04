import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

Future<void> main() async {
  await Application(
    title: 'Text Modifiers Example',
  ).runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) => draw(frame),
  );
}

const List<Color> _colors = [
  Color.black,
  Color.darkGray,
  Color.gray,
  Color.white,
  Color.red,
];

final List<MapEntry<String, Modifier>> _modifiers = Modifier.list.entries.toList();

void draw(Frame frame) {
  final ui = plume.Column<PaintToken>(
    crossAxisAlignment: plume.CrossAxisAlignment.stretch,
    children: [
      lineNode(
        Line(
          'Note: Not all terminals support all modifiers',
          style: const Style(fg: Color.red, addModifier: Modifier.bold),
        ),
      ),
      plume.Expanded<PaintToken>(child: _modifiersGrid()),
    ],
  );

  frame.renderNode(ui);
}

/// 25 background/foreground combinations, two rows of five modifiers each.
plume.RenderNode<PaintToken> _modifiersGrid() {
  final rows = <plume.RenderNode<PaintToken>>[];
  for (final bg in _colors) {
    for (final fg in _colors) {
      rows
        ..add(_modifierRow(fg: fg, bg: bg, start: 0))
        ..add(_modifierRow(fg: fg, bg: bg, start: 5));
    }
  }
  return plume.Column<PaintToken>(children: rows);
}

plume.RenderNode<PaintToken> _modifierRow({required Color fg, required Color bg, required int start}) {
  return plume.Row<PaintToken>(
    children: [
      for (var i = start; i < start + 5; i++) plume.Expanded<PaintToken>(child: _modifierCell(fg, bg, _modifiers[i])),
    ],
  );
}

plume.RenderNode<PaintToken> _modifierCell(Color fg, Color bg, MapEntry<String, Modifier> modifier) {
  final padding = ' ' * (12 - modifier.key.length);
  return lineNode(
    Line(
      '${modifier.key}$padding',
      style: Style(fg: fg, bg: bg, addModifier: modifier.value),
    ),
  );
}
