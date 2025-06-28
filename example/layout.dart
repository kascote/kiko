import 'dart:io';

import 'package:kiko/iterators.dart';
import 'package:kiko/kiko.dart';

Future<void> main() async {
  final term = await init();
  runLoop(term);
  await dispose();
}

void runLoop(Terminal term) {
  term.draw(draw);
  sleep(const Duration(seconds: 3));
}

void draw(Frame frame) {
  final vertical = Layout.vertical(const [
    ConstraintLength(4), //text
    ConstraintLength(50), //examples
    ConstraintMin(0), // fills remaining space
  ]);

  final [textArea, examplesArea, _] = vertical.areas(frame.area);

  frame.renderWidget(
    Text.fromLines([
      Line(
        content: 'Horizontal layout example',
        style: const Style(fg: Color.darkGray),
        alignment: Alignment.center,
      ),
      Line(content: 'Each line has 2 constraints, plus Min(0) to fill the remaining space.'),
      Line(content: 'E.g. the second line of the Len/Min box is [Length(2), Min(2), Min(0)]'),
      Line(content: "Note: constraint labels that don't fit are truncated"),
    ]),
    textArea,
  );

  final vertRows = Layout.vertical(const [
    ConstraintLength(9),
    ConstraintLength(9),
    ConstraintLength(9),
    ConstraintLength(9),
    ConstraintLength(9),
    ConstraintMin(0), // fills remaining space
  ]);
  final exampleRows = vertRows.split(examplesArea);

  final exampleAreas = exampleRows
      .map(
        (area) => Layout.horizontal(const [
          ConstraintLength(14),
          ConstraintLength(14),
          ConstraintLength(14),
          ConstraintLength(14),
          ConstraintLength(14),
          ConstraintMin(0), // fills remaining space
        ]).split(area).take(5),
      )
      .expand((a) => a)
      .toList();

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
      ]
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
      ]
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
      ]
    ),
    (
      'Perc',
      const [
        ConstraintPercentage(0),
        ConstraintPercentage(25),
        ConstraintPercentage(50),
        ConstraintPercentage(75),
        ConstraintPercentage(100),
        ConstraintPercentage(150),
      ]
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
      ]
    ),
  ];

  for (final ((a, b), area) in examples.cartesianProduct(examples).zip(exampleAreas)) {
    final (nameA, exampleA) = a;
    final (nameB, exampleB) = b;
    final constraints = exampleA.zip(exampleB);
    renderExampleCombination(frame, area, '$nameA/$nameB', constraints);
  }

  stderr.writeln('cache1 ${layoutCacheStats()}');
}

void renderExampleCombination(Frame frame, Rect area, String title, Iterable<(Constraint, Constraint)> constraints) {
  final block = Block(
    borders: Borders.all,
    style: const Style.reset(),
    borderStyle: const Style(fg: Color.darkGray),
  )..titleTop(
      Line(
        content: title,
        style: const Style(fg: Color.green),
        alignment: Alignment.left,
      ),
    );
  final inner = block.inner(area);
  frame.renderWidget(block, area);

  final layout = Layout.vertical(List.generate(constraints.length + 1, (_) => const ConstraintLength(1))).split(inner);
  for (final ((a, b), area) in constraints.zip(layout)) {
    renderSingleExample(frame, area, [a, b, const ConstraintMin(0)]);
  }

  frame.renderWidget(Text.raw('123456789012'), layout[6]);
}

void renderSingleExample(Frame frame, Rect area, List<Constraint> constraints) {
  final red = Text.raw(constraintLabel(constraints[0]), style: const Style(bg: Color.red));
  final blue = Text.raw(constraintLabel(constraints[1]), style: const Style(bg: Color.blue));
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
    ConstraintPercentage(:final value) ||
    ConstraintFill(:final value) =>
      value.toString(),
  };
}
