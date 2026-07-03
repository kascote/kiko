import 'dart:io';

import 'package:kiko/iterators.dart';
import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;

Future<void> main() async {
  await Application(
    title: 'Layout proportions Example',
    onCleanup: (terminal) async {
      stderr.writeln('layoutCache ${layoutCacheStats()}');
    },
  ).runStateless(
    update: (_, msg) => switch (msg) {
      KeyMsg(key: 'q') => (null, const Quit()),
      _ => (null, null),
    },
    view: (_, frame) => draw(frame),
  );
}

// Cell sizes for the example grid, in cells.
const _cellWidth = 14;
const _cellHeight = 9;

void draw(Frame frame) {
  // The screen is a plume tree now: a stretched column of a header, five rows
  // of example cells, and a spacer that eats the rest of the height. Each cell
  // and the header are still drawn by the un-ported kiko widgets below, wrapped
  // as LegacyLeaf so only the outer layout moved to plume.
  final examples = [
    (
      'Len',
      const [
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
      const [
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
      const [
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
      const [
        ConstraintPercent(0),
        ConstraintPercent(25),
        ConstraintPercent(50),
        ConstraintPercent(75),
        ConstraintPercent(100),
        ConstraintPercent(150),
      ],
    ),
    (
      'Ratio',
      const [
        ConstraintRatio(0, 4),
        ConstraintRatio(1, 4),
        ConstraintRatio(2, 4),
        ConstraintRatio(3, 4),
        ConstraintRatio(4, 4),
        ConstraintRatio(6, 4),
      ],
    ),
  ];

  final rows = <plume.RenderNode<PaintToken>>[];
  for (final (nameA, exampleA) in examples) {
    final cells = <plume.RenderNode<PaintToken>>[];
    for (final (nameB, exampleB) in examples) {
      final constraints = exampleA.zip(exampleB).toList();
      cells.add(
        LegacyLeaf(
          _FnWidget((area, frame) => renderExampleCombination(frame, area, '$nameA/$nameB', constraints)),
          width: _cellWidth,
          height: _cellHeight,
        ),
      );
    }
    cells.add(_fill());
    rows.add(plume.Row<PaintToken>(children: cells));
  }

  final header = Text.fromLines([
    Line(
      'Horizontal layout example',
      style: const Style(fg: Color.darkGray),
      alignment: Alignment.center,
    ),
    Line('Each line has 2 constraints, plus Min(0) to fill the remaining space.'),
    Line('E.g. the second line of the Len/Min box is [Length(2), Min(2), Min(0)]'),
    Line("Note: constraint labels that don't fit are truncated"),
  ]);

  frame.renderNode(
    plume.Column<PaintToken>(
      crossAxisAlignment: plume.CrossAxisAlignment.stretch,
      children: [
        LegacyLeaf(
          _FnWidget((area, frame) => frame.renderWidget(header, area)),
          width: 0,
          height: 4,
        ),
        ...rows,
        _fill(),
      ],
    ),
  );
}

/// A flexible spacer that soaks up leftover space, matching the old
/// `ConstraintMin(0)` fill regions.
plume.Expanded<PaintToken> _fill() => plume.Expanded<PaintToken>(child: plume.SizedBox<PaintToken>());

/// Adapts a `render(Rect, Frame)` closure into a kiko [Widget] so an un-ported
/// bit of drawing can ride inside a [LegacyLeaf].
class _FnWidget implements Widget {
  _FnWidget(this._render);

  final void Function(Rect area, Frame frame) _render;

  @override
  void render(Rect area, Frame frame) => _render(area, frame);
}

void renderExampleCombination(
  Frame frame,
  Rect area,
  String title,
  Iterable<(Constraint, Constraint)> constraints,
) {
  final block =
      const Block(
        borders: Borders.all,
        style: Style.reset(),
        borderStyle: Style(fg: Color.darkGray),
      ).titleTop(
        Line(
          title,
          style: const Style(fg: Color.green),
          alignment: Alignment.left,
        ),
      );
  final inner = block.inner(area);
  frame.renderWidget(block, area);

  final layout = Layout.vertical(
    List.generate(constraints.length + 1, (_) => const ConstraintLength(1)),
  ).split(inner);
  for (final ((a, b), area) in constraints.zip(layout)) {
    renderSingleExample(frame, area, [a, b, const ConstraintMin(0)]);
  }

  frame.renderWidget(Text.raw('123456789012'), layout[6]);
}

void renderSingleExample(Frame frame, Rect area, List<Constraint> constraints) {
  final red = Text.raw(
    constraintLabel(constraints[0]),
    style: const Style(bg: Color.red),
  );
  final blue = Text.raw(
    constraintLabel(constraints[1]),
    style: const Style(bg: Color.blue),
  );
  final green = Text.raw('.' * 12, style: const Style(bg: Color.green));
  final horizontal = Layout.horizontal(constraints);
  final [redArea, blueArea, greenArea] = horizontal.areas(area);
  frame
    ..renderWidget(red, redArea)
    ..renderWidget(blue, blueArea)
    ..renderWidget(green, greenArea);
}

String constraintLabel(Constraint constraint) {
  return switch (constraint) {
    ConstraintRatio(:final numerator, :final denominator) => '$numerator:$denominator',
    ConstraintLength(:final value) ||
    ConstraintMin(:final value) ||
    ConstraintMax(:final value) ||
    ConstraintPercent(:final value) ||
    ConstraintFill(:final value) => value.toString(),
  };
}
