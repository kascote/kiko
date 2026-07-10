import 'package:kiko/kiko.dart';

Future<void> main() async {
  await Application(
    title: 'Text Modifiers Example',
  ).runStateless(
    update: (_, msg, _) => switch (msg) {
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
  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Line(
        'Note: Not all terminals support all modifiers',
        style: const Style(fg: Color.red, addModifier: Modifier.bold),
      ),
      Expanded(child: _modifiersGrid()),
    ],
  );

  frame.render(ui);
}

/// 25 background/foreground combinations, two rows of five modifiers each.
View _modifiersGrid() {
  final rows = <View>[];
  for (final bg in _colors) {
    for (final fg in _colors) {
      rows
        ..add(_modifierRow(fg: fg, bg: bg, start: 0))
        ..add(_modifierRow(fg: fg, bg: bg, start: 5));
    }
  }
  return Column(children: rows);
}

View _modifierRow({required Color fg, required Color bg, required int start}) {
  return Row(
    children: [
      for (var i = start; i < start + 5; i++) Expanded(child: _modifierCell(fg, bg, _modifiers[i])),
    ],
  );
}

View _modifierCell(Color fg, Color bg, MapEntry<String, Modifier> modifier) {
  final padding = ' ' * (12 - modifier.key.length);
  return Line(
    '${modifier.key}$padding',
    style: Style(fg: fg, bg: bg, addModifier: modifier.value),
  );
}
