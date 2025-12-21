import 'dart:io';

import 'package:kiko/iterators.dart';
import 'package:kiko/kiko.dart';

Future<void> main() async {
  await Application(
    title: 'Color Demo',
    onCleanup: (terminal) async {
      stdout.writeln('layoutCache ${layoutCacheStats()}');
    },
  ).runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) {
      final layout = Layout.vertical(const [
        ConstraintLength(30),
        ConstraintLength(17),
        ConstraintMin(2),
      ]).split(frame.area);

      renderNamedColors(frame, layout[0]);
      renderIndexedColors(frame, layout[1]);
      renderIndexedGrayScale(frame, layout[2]);
    },
  );
}

final List<Color> colors = [
  Color.black,
  Color.red,
  Color.green,
  Color.yellow,
  Color.blue,
  Color.magenta,
  Color.cyan,
  Color.gray,
  Color.darkGray,
  Color.brightRed,
  Color.brightGreen,
  Color.brightYellow,
  Color.brightBlue,
  Color.brightMagenta,
  Color.brightCyan,
  Color.white,
];

final colorNames = [
  'Black',
  'Red',
  'Green',
  'Yellow',
  'Blue',
  'Magenta',
  'Cyan',
  'Gray',
  'DarkGray',
  'LightRed',
  'LightGreen',
  'LightYellow',
  'LightBlue',
  'LightMagenta',
  'LightCyan',
  'White',
];

void renderNamedColors(Frame frame, Rect area) {
  final layout = Layout.vertical(List.generate(10, (_) => const ConstraintLength(3))).split(area);

  renderNamedColorFg(frame, 'reset', Color.reset, layout[0]);
  renderNamedColorFg(frame, 'black', Color.black, layout[1]);
  renderNamedColorFg(frame, 'darkGray', Color.darkGray, layout[2]);
  renderNamedColorFg(frame, 'gray', Color.gray, layout[3]);
  renderNamedColorFg(frame, 'white', Color.white, layout[4]);

  renderNamedColorBg(frame, 'reset', Color.reset, layout[5]);
  renderNamedColorBg(frame, 'black', Color.black, layout[6]);
  renderNamedColorBg(frame, 'darkGray', Color.darkGray, layout[7]);
  renderNamedColorBg(frame, 'gray', Color.gray, layout[8]);
  renderNamedColorBg(frame, 'white', Color.white, layout[9]);
}

void renderNamedColorFg(Frame frame, String nameCol, Color bg, Rect area) {
  final block = titleBlock('Foreground colors on $nameCol background');
  final inner = block.inner(area);
  frame.renderWidget(block, area);

  final layout = Layout.vertical(
    List.generate(2, (_) => const ConstraintLength(1)),
  ).split(inner);
  final areas = layout
      .map(
        (area) => Layout.horizontal(
          List.generate(8, (_) => const ConstraintRatio(1, 8)),
        ).split(area),
      )
      .expand((x) => x);

  for (final (index, fg, area) in colors.zipIndex(areas)) {
    final colorName = colorNames[index];
    final text = Text.raw(
      colorName,
      style: Style(fg: fg, bg: bg),
    );
    frame.renderWidget(text, area);
  }
}

void renderNamedColorBg(Frame frame, String nameCol, Color fg, Rect area) {
  final block = titleBlock('Background colors with $nameCol foreground');
  final inner = block.inner(area);
  frame.renderWidget(block, area);

  final layout = Layout.vertical(
    List.generate(2, (_) => const ConstraintLength(1)),
  ).split(inner);
  final areas = layout
      .map(
        (area) => Layout.horizontal(
          List.generate(8, (_) => const ConstraintRatio(1, 8)),
        ).split(area),
      )
      .expand((x) => x);

  for (final (index, bg, area) in colors.zipIndex(areas)) {
    final colorName = colorNames[index];
    final text = Text.raw(
      colorName,
      style: Style(fg: fg, bg: bg),
    );
    frame.renderWidget(text, area);
  }
}

void renderIndexedColors(Frame frame, Rect area) {
  final block = titleBlock('Indexed colors');
  final inner = block.inner(area);
  frame.renderWidget(block, area);

  final layout = Layout.vertical(const [
    ConstraintLength(1), // 0 - 15
    ConstraintLength(1), // blank
    ConstraintMin(6), // 16-123
    ConstraintLength(1), // blank
    ConstraintMin(6), // 124-231
    ConstraintLength(1),
  ]).split(inner);

  final colorLayout = Layout.horizontal(
    List.generate(16, (_) => const ConstraintLength(5)),
  ).split(layout[0]);
  for (var i = 0; i < 16; i++) {
    final color = Color.indexed(i);
    final colorIndex = i.toString().padLeft(2, '0');
    final bg = i < 1 ? Color.darkGray : Color.black;
    final text = Line.fromSpans([
      Span(
        colorIndex,
        style: Style(fg: color, bg: bg),
      ),
      Span(
        '  ',
        style: Style(fg: color, bg: color),
      ),
    ]);
    frame.renderWidget(text, colorLayout[i]);
  }

  final indexLayout = [layout[2], layout[4]]
      .map(
        (a) => Layout.horizontal(
          List.generate(3, (_) => const ConstraintLength(27)),
        ).split(a),
      )
      .expand((x) => x)
      .map(
        (a) => Layout.vertical(
          List.generate(6, (_) => const ConstraintLength(1)),
        ).split(a),
      )
      .expand((x) => x)
      .map(
        (a) => Layout.horizontal(
          List.generate(6, (_) => const ConstraintMin(4)),
        ).split(a),
      )
      .expand((x) => x);

  for (var i = 16; i <= 231; i++) {
    final color = Color.indexed(i);
    final colorIndex = i.toString().padLeft(3, '0');
    final text = Line.fromSpans([
      Span(
        colorIndex,
        style: Style(fg: color, bg: Color.reset),
      ),
      Span(
        '.',
        style: Style(fg: color, bg: color),
      ),
      const Span('   '),
      //const Span(content: '███'),
    ]);
    frame.renderWidget(text, indexLayout.elementAt(i - 16));
  }
}

void renderIndexedGrayScale(Frame frame, Rect area) {
  final layout =
      Layout.vertical(const [
            ConstraintLength(1), // 232-243
            ConstraintLength(1), // 244-255
          ])
          .split(area)
          .map(
            (a) => Layout.horizontal(
              List.generate(12, (_) => const ConstraintLength(6)),
            ).split(a),
          )
          .expand((x) => x)
          .toList();

  for (var i = 232; i <= 255; i++) {
    final color = Color.indexed(i);
    final colorIndex = i.toString().padLeft(3, '0');
    final bg = i < 244 ? Color.gray : Color.black;
    final text = Line.fromSpans([
      Span(
        colorIndex,
        style: Style(fg: color, bg: bg),
      ),
      Span(
        '  ',
        style: Style(fg: color, bg: color),
      ),
      const Span('       '),
    ]);
    frame.renderWidget(text, layout[i - 232]);
  }
}

Block titleBlock(String title) {
  return const Block(
    borders: Borders.top,
    borderStyle: Style(fg: Color.darkGray),
    titlesStyle: Style(fg: Color.reset),
  ).titleTop(Line(title, alignment: Alignment.center));
}
