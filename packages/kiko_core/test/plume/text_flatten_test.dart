import 'package:kiko/kiko.dart' hide Text;
import 'package:kiko/kiko.dart' as kiko show Text;
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

String _dump(Buffer buffer) {
  final out = StringBuffer();
  final area = buffer.area;
  for (var y = area.top; y < area.bottom; y++) {
    final row = StringBuffer();
    for (var x = area.left; x < area.right; x++) {
      final cell = buffer[(x: x, y: y)];
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}

void main() {
  group('spanRun', () {
    test('carries the span content and its style over the base', () {
      final run = spanRun(
        const Span('hi', style: Style(fg: Color.red)),
        base: const Style(fg: Color.blue, bg: Color.green),
      );

      // fg from the span wins; bg from the base carries through.
      final expected = const Style(fg: Color.blue, bg: Color.green).patch(const Style(fg: Color.red));
      expect(run, plume.TextRun<PaintToken>('hi', PaintToken(expected)));
    });

    test('uses the span style alone when no base is given', () {
      final run = spanRun(const Span('x', style: Style(fg: Color.red)));
      expect(run.token, const PaintToken(Style(fg: Color.red)));
    });
  });

  group('lineNode', () {
    test('resolves each run through base then line then span', () {
      final line = Line.fromSpans(
        const <Span>[
          Span('a', style: Style(fg: Color.red)),
          Span('b', style: Style(addModifier: Modifier.bold)),
        ],
        style: const Style(bg: Color.green),
      );

      final node = lineNode(line, base: const Style(fg: Color.blue));

      const lineBase = Style(fg: Color.blue);
      final withLine = lineBase.patch(const Style(bg: Color.green));
      expect(node.runs, <plume.TextRun<PaintToken>>[
        plume.TextRun<PaintToken>('a', PaintToken(withLine.patch(const Style(fg: Color.red)))),
        plume.TextRun<PaintToken>('b', PaintToken(withLine.patch(const Style(addModifier: Modifier.bold)))),
      ]);
    });

    test('takes alignment from the line when it sets one', () {
      final node = lineNode(Line('centered', alignment: Alignment.center));
      expect(node.align, plume.TextAlign.center);
    });

    test('falls back to the given alignment when the line has none', () {
      final node = lineNode(Line('t'), fallbackAlign: Alignment.right);
      expect(node.align, plume.TextAlign.end);
    });

    test('defaults to the left when neither the line nor a fallback aligns', () {
      final node = lineNode(Line('t'));
      expect(node.align, plume.TextAlign.start);
    });
  });

  group('mapAlign', () {
    test('maps every kiko alignment, treating null as the left', () {
      expect(mapAlign(null), plume.TextAlign.start);
      expect(mapAlign(Alignment.left), plume.TextAlign.start);
      expect(mapAlign(Alignment.center), plume.TextAlign.center);
      expect(mapAlign(Alignment.right), plume.TextAlign.end);
    });
  });

  group('textNode', () {
    test('a single-line text is one bare text node', () {
      final node = textNode(kiko.Text(<Line>[Line('hi')]));
      expect(node, isA<plume.Text<PaintToken>>());
    });

    test('a multi-line text is a stretched column of lines', () {
      final node = textNode(kiko.Text(<Line>[Line('a'), Line('b')]));
      expect(node, isA<plume.Column<PaintToken>>());
      final column = node as plume.Column<PaintToken>;
      expect(column.crossAxisAlignment, plume.CrossAxisAlignment.stretch);
    });

    test('resolves the style chain base then text then line then span', () {
      final text = kiko.Text(
        <Line>[
          Line.fromSpans(const <Span>[Span('x', style: Style(fg: Color.red))], style: const Style(bg: Color.green)),
        ],
        style: const Style(addModifier: Modifier.bold),
      );
      final node = textNode(text, base: const Style(fg: Color.blue)) as plume.Text<PaintToken>;

      final expected = const Style(fg: Color.blue)
          .patch(const Style(addModifier: Modifier.bold))
          .patch(const Style(bg: Color.green))
          .patch(const Style(fg: Color.red));
      expect(node.runs.single, plume.TextRun<PaintToken>('x', PaintToken(expected)));
    });

    test('keeps each line on its own alignment when rendered', () {
      final text = kiko.Text(<Line>[
        Line('ab', alignment: Alignment.left),
        Line('cd', alignment: Alignment.right),
      ]);
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 2));
      Frame(buffer.area, buffer, 0).renderNode(textNode(text));
      expect(_dump(buffer), 'ab\n  cd\n');
    });
  });
}
