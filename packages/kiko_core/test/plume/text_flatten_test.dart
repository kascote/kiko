import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

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
}
