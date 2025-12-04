import 'dart:io';

import 'package:kiko/iterators.dart';
import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart';

Future<void> main() async {
  await Application(
    title: 'Layout proportions Example (Declarative)',
    onCleanup: (terminal) async {
      stderr.writeln('layoutCache ${layoutCacheStats()}');
    },
  ).run(
    render: draw,
    onEvent: (event) {
      if (event is KeyEvent && event.code.char == 'q') return 0;
      return null;
    },
  );
}

void draw(Frame frame) {
  final ui = Column(
    children: [
      Fixed(
        4,
        child: const Header(
          title: 'Horizontal layout example',
          lines: [
            'Each line has 2 constraints, plus Min(0) to fill the remaining space.',
            'E.g. the second line of the Len/Min box is [Length(2), Min(2), Min(0)]',
            "Note: constraint labels that don't fit are truncated",
          ],
        ),
      ),
      Fixed(
        50,
        child: Grid(
          rows: 5,
          columns: 5,
          rowConstraint: const ConstraintLength(9),
          columnConstraint: const ConstraintLength(14),
          cellBuilder: (row, column) => ConstraintDemoCell(
            title: '${examples[row].$1}/${examples[column].$1}',
            constraints: examples[row].$2.zip(examples[column].$2),
          ),
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (rect) => DebugPanel(rect: rect),
        ),
      ),
    ],
  );

  frame.renderWidget(ui, frame.area);
}

// Example constraint definitions
const List<(String, List<Constraint>)> examples = [
  (
    'Len',
    [
      ConstraintLength(0),
      ConstraintLength(2),
      ConstraintLength(3),
      ConstraintLength(6),
      ConstraintLength(10),
      ConstraintLength(15),
    ],
  ),
  (
    'Min',
    [
      ConstraintMin(0),
      ConstraintMin(2),
      ConstraintMin(3),
      ConstraintMin(6),
      ConstraintMin(10),
      ConstraintMin(15),
    ],
  ),
  (
    'Max',
    [
      ConstraintMax(0),
      ConstraintMax(2),
      ConstraintMax(3),
      ConstraintMax(6),
      ConstraintMax(10),
      ConstraintMax(15),
    ],
  ),
  (
    'Perc',
    [
      ConstraintPercentage(0),
      ConstraintPercentage(25),
      ConstraintPercentage(50),
      ConstraintPercentage(75),
      ConstraintPercentage(100),
      ConstraintPercentage(150),
    ],
  ),
  (
    'Ratio',
    [
      ConstraintRatio(0, 4),
      ConstraintRatio(1, 4),
      ConstraintRatio(2, 4),
      ConstraintRatio(3, 4),
      ConstraintRatio(4, 4),
      ConstraintRatio(6, 4),
    ],
  ),
];

/// Reusable header widget for the demo.
class Header implements Widget {
  final String title;
  final List<String> lines;

  const Header({required this.title, required this.lines});

  @override
  void render(Rect area, Frame frame) {
    frame.renderWidget(
      Text.fromLines([
        Line(
          content: title,
          style: const Style(fg: Color.darkGray),
          alignment: Alignment.center,
        ),
        ...lines.map((l) => Line(content: l)),
      ]),
      area,
    );
  }
}

/// Reusable demo cell showing constraint combinations.
class ConstraintDemoCell implements Widget {
  final String title;
  final Iterable<(Constraint, Constraint)> constraints;

  const ConstraintDemoCell({
    required this.title,
    required this.constraints,
  });

  @override
  void render(Rect area, Frame frame) {
    final block =
        const Block(
          borders: Borders.all,
          style: Style.reset(),
          borderStyle: Style(fg: Color.darkGray),
        ).titleTop(
          Line(
            content: title,
            style: const Style(fg: Color.green),
            alignment: Alignment.left,
          ),
        );

    frame.renderWidget(block, area);
    final inner = block.inner(area);

    Column(
      children: [
        ...constraints.map(
          (pair) => Fixed(
            1,
            child: _ConstraintRow(constraints: [pair.$1, pair.$2, const ConstraintMin(0)]),
          ),
        ),
        Fixed(1, child: Text.raw('123456789012')),
      ],
    ).render(inner, frame);
  }
}

/// A single row showing constraint visualization.
class _ConstraintRow implements Widget {
  final List<Constraint> constraints;

  const _ConstraintRow({required this.constraints});

  @override
  void render(Rect area, Frame frame) {
    final layout = Layout.horizontal(constraints);
    final [redArea, blueArea, greenArea] = layout.areas(area);

    frame
      ..renderWidget(
        Text.raw(_constraintLabel(constraints[0]), style: const Style(bg: Color.red)),
        redArea,
      )
      ..renderWidget(
        Text.raw(_constraintLabel(constraints[1]), style: const Style(bg: Color.blue)),
        blueArea,
      )
      ..renderWidget(
        Text.raw('.' * 12, style: const Style(bg: Color.green)),
        greenArea,
      );
  }
}

String _constraintLabel(Constraint constraint) {
  return switch (constraint) {
    ConstraintRatio(:final numerator, :final denominator) => '$numerator:$denominator',
    ConstraintLength(:final value) ||
    ConstraintMin(:final value) ||
    ConstraintMax(:final value) ||
    ConstraintPercentage(:final value) ||
    ConstraintFill(:final value) => value.toString(),
  };
}

/// Debug panel showing layout info.
class DebugPanel implements Widget {
  final Rect rect;

  const DebugPanel({required this.rect});

  @override
  void render(Rect area, Frame frame) {
    frame.renderWidget(
      Text.fromLines([
        Line(content: 'Debug Panel'),
        Line(content: 'Area: ${rect.width}x${rect.height} at (${rect.x}, ${rect.y})'),
      ]),
      area,
    );
  }
}
