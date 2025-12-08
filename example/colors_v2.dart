import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart';

Future<void> main() async {
  await Application(
    title: 'Color Demo (Declarative)',
    onCleanup: (terminal) async {
      stdout.writeln('layoutCache ${layoutCacheStats()}');
    },
  ).run(
    render: (frame) {
      final ui = Column(
        children: [
          Fixed(30, child: NamedColorsPanel()),
          Fixed(17, child: IndexedColorsPanel()),
          MinSize(2, child: GrayScalePanel()),
        ],
      );
      frame.renderWidget(ui, frame.area);
    },
    onEvent: (event) {
      if (event is KeyEvent && event.code.char == 'q') return 0;
      return null;
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

/// Panel showing named colors with foreground/background variations.
class NamedColorsPanel implements Widget {
  @override
  void render(Rect area, Frame frame) {
    Column(
      children: [
        Fixed(
          3,
          child: const NamedColorRow(label: 'reset', bg: Color.reset, isForeground: true),
        ),
        Fixed(
          3,
          child: const NamedColorRow(label: 'black', bg: Color.black, isForeground: true),
        ),
        Fixed(
          3,
          child: const NamedColorRow(label: 'darkGray', bg: Color.darkGray, isForeground: true),
        ),
        Fixed(
          3,
          child: const NamedColorRow(label: 'gray', bg: Color.gray, isForeground: true),
        ),
        Fixed(
          3,
          child: const NamedColorRow(label: 'white', bg: Color.white, isForeground: true),
        ),
        Fixed(
          3,
          child: const NamedColorRow(label: 'reset', fg: Color.reset, isForeground: false),
        ),
        Fixed(
          3,
          child: const NamedColorRow(label: 'black', fg: Color.black, isForeground: false),
        ),
        Fixed(
          3,
          child: const NamedColorRow(label: 'darkGray', fg: Color.darkGray, isForeground: false),
        ),
        Fixed(
          3,
          child: const NamedColorRow(label: 'gray', fg: Color.gray, isForeground: false),
        ),
        Fixed(
          3,
          child: const NamedColorRow(label: 'white', fg: Color.white, isForeground: false),
        ),
      ],
    ).render(area, frame);
  }
}

/// A row showing color names with a specific background or foreground.
class NamedColorRow implements Widget {
  final String label;
  final Color? bg;
  final Color? fg;
  final bool isForeground;

  const NamedColorRow({
    required this.label,
    required this.isForeground,
    this.bg,
    this.fg,
  });

  @override
  void render(Rect area, Frame frame) {
    final title = isForeground ? 'Foreground colors on $label background' : 'Background colors with $label foreground';
    final block = titleBlock(title);
    final inner = block.inner(area);
    frame.renderWidget(block, area);

    final rowChildren = <LayoutChild>[];
    for (var i = 0; i < 8; i++) {
      rowChildren.add(
        ConstraintChild(
          const ConstraintRatio(1, 8),
          child: _ColorCell(
            name: colorNames[i],
            fg: isForeground ? colors[i] : fg!,
            bg: isForeground ? bg! : colors[i],
          ),
        ),
      );
    }
    final row2Children = <LayoutChild>[];
    for (var i = 8; i < 16; i++) {
      row2Children.add(
        ConstraintChild(
          const ConstraintRatio(1, 8),
          child: _ColorCell(
            name: colorNames[i],
            fg: isForeground ? colors[i] : fg!,
            bg: isForeground ? bg! : colors[i],
          ),
        ),
      );
    }

    Column(
      children: [
        Fixed(1, child: Row(children: rowChildren)),
        Fixed(1, child: Row(children: row2Children)),
      ],
    ).render(inner, frame);
  }
}

class _ColorCell implements Widget {
  final String name;
  final Color fg;
  final Color bg;

  const _ColorCell({required this.name, required this.fg, required this.bg});

  @override
  void render(Rect area, Frame frame) {
    Text.raw(
      name,
      style: Style(fg: fg, bg: bg),
    ).render(area, frame);
  }
}

/// Panel showing indexed colors (0-231).
class IndexedColorsPanel implements Widget {
  @override
  void render(Rect area, Frame frame) {
    final block = titleBlock('Indexed colors');
    final inner = block.inner(area);
    frame.renderWidget(block, area);

    Column(
      children: [
        Fixed(1, child: _IndexedRow16()),
        Fixed(1, child: EmptyWidget()),
        MinSize(6, child: const _IndexedColorBlock(startIndex: 16, endIndex: 123)),
        Fixed(1, child: EmptyWidget()),
        MinSize(6, child: const _IndexedColorBlock(startIndex: 124, endIndex: 231)),
        Fixed(1, child: EmptyWidget()),
      ],
    ).render(inner, frame);
  }
}

/// First 16 indexed colors row.
class _IndexedRow16 implements Widget {
  @override
  void render(Rect area, Frame frame) {
    final children = <LayoutChild>[];
    for (var i = 0; i < 16; i++) {
      children.add(Fixed(5, child: _IndexedColorCell16(index: i)));
    }
    Row(children: children).render(area, frame);
  }
}

class _IndexedColorCell16 implements Widget {
  final int index;
  const _IndexedColorCell16({required this.index});

  @override
  void render(Rect area, Frame frame) {
    final color = Color.indexed(index);
    final colorIndex = index.toString().padLeft(2, '0');
    final bg = index < 1 ? Color.darkGray : Color.black;
    Line.fromSpans([
      Span(
        colorIndex,
        style: Style(fg: color, bg: bg),
      ),
      Span(
        '  ',
        style: Style(fg: color, bg: color),
      ),
    ]).render(area, frame);
  }
}

/// Block of indexed colors (6x6 grids).
class _IndexedColorBlock implements Widget {
  final int startIndex;
  final int endIndex;

  const _IndexedColorBlock({required this.startIndex, required this.endIndex});

  @override
  void render(Rect area, Frame frame) {
    // 3 groups of 6x6 colors per block, arranged in 3 columns
    final colChildren = <LayoutChild>[];
    var idx = startIndex;
    for (var group = 0; group < 3 && idx <= endIndex; group++) {
      final groupChildren = <LayoutChild>[];
      for (var row = 0; row < 6 && idx <= endIndex; row++) {
        final rowChildren = <LayoutChild>[];
        for (var col = 0; col < 6 && idx <= endIndex; col++) {
          rowChildren.add(MinSize(4, child: _IndexedColorCellSmall(index: idx)));
          idx++;
        }
        groupChildren.add(Fixed(1, child: Row(children: rowChildren)));
      }
      colChildren.add(Fixed(27, child: Column(children: groupChildren)));
    }
    Row(children: colChildren).render(area, frame);
  }
}

class _IndexedColorCellSmall implements Widget {
  final int index;
  const _IndexedColorCellSmall({required this.index});

  @override
  void render(Rect area, Frame frame) {
    final color = Color.indexed(index);
    final colorIndex = index.toString().padLeft(3, '0');
    Line.fromSpans([
      Span(
        colorIndex,
        style: Style(fg: color, bg: Color.reset),
      ),
      Span(
        '.',
        style: Style(fg: color, bg: color),
      ),
    ]).render(area, frame);
  }
}

/// Panel showing grayscale colors (232-255).
class GrayScalePanel implements Widget {
  @override
  void render(Rect area, Frame frame) {
    Column(
      children: [
        Fixed(1, child: const _GrayScaleRow(startIndex: 232)),
        Fixed(1, child: const _GrayScaleRow(startIndex: 244)),
      ],
    ).render(area, frame);
  }
}

class _GrayScaleRow implements Widget {
  final int startIndex;
  const _GrayScaleRow({required this.startIndex});

  @override
  void render(Rect area, Frame frame) {
    final children = <LayoutChild>[];
    for (var i = startIndex; i < startIndex + 12; i++) {
      children.add(Fixed(6, child: _GrayScaleCell(index: i)));
    }
    Row(children: children).render(area, frame);
  }
}

class _GrayScaleCell implements Widget {
  final int index;
  const _GrayScaleCell({required this.index});

  @override
  void render(Rect area, Frame frame) {
    final color = Color.indexed(index);
    final colorIndex = index.toString().padLeft(3, '0');
    final bg = index < 244 ? Color.gray : Color.black;
    Line.fromSpans([
      Span(
        colorIndex,
        style: Style(fg: color, bg: bg),
      ),
      Span(
        '  ',
        style: Style(fg: color, bg: color),
      ),
    ]).render(area, frame);
  }
}

Block titleBlock(String title) {
  return const Block(
    borders: Borders.top,
    borderStyle: Style(fg: Color.darkGray),
    titlesStyle: Style(fg: Color.reset),
  ).titleTop(Line(title, alignment: Alignment.center));
}

/// Empty widget for spacing.
class EmptyWidget implements Widget {
  @override
  void render(Rect area, Frame frame) {}
}
