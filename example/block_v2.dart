import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart' as evt;

Future<void> main() async {
  await Application(
    title: 'Block Example (Declarative)',
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

final _placeHolderText = Text.raw(
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
  style: const Style(fg: Color.darkGray),
);

void draw(Frame frame) {
  final ui = Column(
    children: [
      Fixed(
        1,
        child: Text.raw(
          'Block example. Press q to quit',
          style: const Style(fg: Color.darkGray),
          alignment: Alignment.center,
        ),
      ),
      Expanded(
        child: const Grid(
          rows: 9,
          columns: 2,
          rowConstraint: ConstraintMax(4),
          columnConstraint: ConstraintPercent(50),
          cellBuilder: _buildCell,
        ),
      ),
    ],
  );

  frame.renderWidget(ui, frame.area);
}

Widget _buildCell(int row, int column) {
  final index = row * 2 + column;
  return switch (index) {
    0 => const _BordersDemo(Borders.all, 'ALL'),
    1 => const _BordersDemo(Borders.none, 'NONE'),
    2 => const _BordersDemo(Borders.left, 'LEFT'),
    3 => const _BordersDemo(Borders.right, 'RIGHT'),
    4 => const _BordersDemo(Borders.top, 'TOP'),
    5 => const _BordersDemo(Borders.bottom, 'BOTTOM'),
    6 => const _BorderTypeDemo(BorderType.plain, 'PLAIN'),
    7 => const _BorderTypeDemo(BorderType.rounded, 'ROUNDED'),
    8 => const _BorderTypeDemo(BorderType.double, 'DOUBLE'),
    9 => const _BorderTypeDemo(BorderType.thick, 'THICK'),
    10 => _StyledBlockDemo(),
    11 => _StyledBorderDemo(),
    12 => _StyledTitleDemo(),
    13 => _StyledTitleContentDemo(),
    14 => _MultipleTitlesDemo(),
    15 => _MultipleTitlePositionsDemo(),
    16 => _PaddingDemo(),
    17 => _NestedBlocksDemo(),
    _ => EmptyWidget(),
  };
}

class _BordersDemo implements Widget {
  final Borders border;
  final String name;

  const _BordersDemo(this.border, this.name);

  @override
  void render(Rect area, Frame frame) {
    Block(
      borders: border,
      child: _placeHolderText,
    ).titleTop(Line('Borders::$name')).render(area, frame);
  }
}

class _BorderTypeDemo implements Widget {
  final BorderType borderType;
  final String name;

  const _BorderTypeDemo(this.borderType, this.name);

  @override
  void render(Rect area, Frame frame) {
    Block(
      borders: Borders.all,
      borderType: borderType,
      child: _placeHolderText,
    ).titleTop(Line('BorderType::$name')).render(area, frame);
  }
}

class _StyledBlockDemo implements Widget {
  @override
  void render(Rect area, Frame frame) {
    Block(
      borders: Borders.all,
      style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
      child: _placeHolderText,
    ).titleTop(Line('Styled block')).render(area, frame);
  }
}

class _StyledBorderDemo implements Widget {
  @override
  void render(Rect area, Frame frame) {
    Block(
      borders: Borders.all,
      borderStyle: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
      child: _placeHolderText,
    ).titleTop(Line('Styled borders')).render(area, frame);
  }
}

class _StyledTitleDemo implements Widget {
  @override
  void render(Rect area, Frame frame) {
    Block(
      borders: Borders.all,
      titlesStyle: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
      child: _placeHolderText,
    ).titleTop(Line('Styled title')).render(area, frame);
  }
}

class _StyledTitleContentDemo implements Widget {
  @override
  void render(Rect area, Frame frame) {
    final title = Line.fromSpans([
      Span(
        'Styled ',
        style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
      ),
      Span(
        'title content',
        style: Style(fg: Color.red, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
      ),
    ]);

    Block(
      borders: Borders.all,
      child: _placeHolderText,
    ).titleTop(title).render(area, frame);
  }
}

class _MultipleTitlesDemo implements Widget {
  @override
  void render(Rect area, Frame frame) {
    Block(borders: Borders.all, child: _placeHolderText)
        .titleTop(
          Line(
            'Multiple',
            style: Style(fg: Color.blue, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
          ),
        )
        .titleTop(
          Line(
            'Titles',
            style: Style(fg: Color.red, bg: Color.white, addModifier: Modifier.bold | Modifier.italic),
          ),
        )
        .render(area, frame);
  }
}

class _MultipleTitlePositionsDemo implements Widget {
  @override
  void render(Rect area, Frame frame) {
    Block(borders: Borders.all, child: _placeHolderText)
        .titleTop(Line('top left', alignment: Alignment.left))
        .titleTop(Line('top center', alignment: Alignment.center))
        .titleTop(Line('top right', alignment: Alignment.right))
        .titleBottom(Line('bottom left', alignment: Alignment.left))
        .titleBottom(Line('bottom center', alignment: Alignment.center))
        .titleBottom(Line('bottom right', alignment: Alignment.right))
        .render(area, frame);
  }
}

class _PaddingDemo implements Widget {
  @override
  void render(Rect area, Frame frame) {
    Block(
      borders: Borders.all,
      padding: const EdgeInsets(left: 5, right: 10, top: 1, bottom: 2),
      child: _placeHolderText,
    ).titleTop(Line('Padding')).render(area, frame);
  }
}

class _NestedBlocksDemo implements Widget {
  @override
  void render(Rect area, Frame frame) {
    Block(
      borders: Borders.all,
      child: const Block(borders: Borders.all).titleTop(Line('Inner block')),
    ).titleTop(Line('Outer block')).render(area, frame);
  }
}

class EmptyWidget implements Widget {
  @override
  void render(Rect area, Frame frame) {}
}
