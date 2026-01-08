import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:test/test.dart';

void main() {
  group('capture', () {
    test('basic widget to string', () {
      final p = Paragraph(content: 'Hello');
      final result = capture(p, width: 10, height: 1);
      expect(result, equals('Hello'));
    });

    test('multiline widget', () {
      final p = Paragraph(content: 'Hello\nWorld');
      final result = capture(p, width: 10, height: 2);
      expect(result, equals('Hello\nWorld'));
    });

    test('trims trailing whitespace by default', () {
      final p = Paragraph(content: 'Hi');
      final result = capture(p, width: 20, height: 1);
      expect(result, equals('Hi'));
    });

    test('preserves trailing with exact mode', () {
      final p = Paragraph(content: 'Hi');
      final result = capture(
        p,
        width: 5,
        height: 1,
        trimTrailingWhitespace: false,
      );
      expect(result, equals('Hi   '));
    });

    test('showEmptyCells replaces spaces with marker', () {
      final p = Paragraph(content: 'A B');
      final result = capture(
        p,
        width: 5,
        height: 1,
        showEmptyCells: true,
        trimTrailingWhitespace: false,
      );
      expect(result, equals('A·B··'));
    });

    test('custom empty cell marker', () {
      final p = Paragraph(content: 'X');
      final result = capture(
        p,
        width: 3,
        height: 1,
        showEmptyCells: true,
        emptyCellMarker: '.',
        trimTrailingWhitespace: false,
      );
      expect(result, equals('X..'));
    });

    test('showBorder adds ASCII border outside', () {
      final p = Paragraph(content: 'Hi');
      final result = capture(p, width: 4, height: 1, showBorder: true);
      expect(
        result,
        equals('''
+----+
|Hi  |
+----+'''),
      );
    });

    test('border with multiline content', () {
      final p = Paragraph(content: 'A\nB');
      final result = capture(p, width: 3, height: 2, showBorder: true);
      expect(
        result,
        equals('''
+---+
|A  |
|B  |
+---+'''),
      );
    });
  });

  group('captureResult', () {
    test('returns CaptureResult with metadata', () {
      final p = Paragraph(content: 'Test');
      final result = captureResult(p, width: 20, height: 5);

      expect(result.content, equals('Test'));
      expect(result.width, equals(20));
      expect(result.height, equals(5));
      expect(result.lines, equals(['Test']));
    });

    test('toString returns content', () {
      final p = Paragraph(content: 'Hello');
      final result = captureResult(p, width: 10, height: 1);
      expect(result.toString(), equals('Hello'));
    });
  });

  group('captureWith', () {
    test('callback receives CaptureTester', () {
      final result = captureWith(
        (t) {
          expect(t.area.width, equals(15));
          expect(t.area.height, equals(3));
          t.render(Paragraph(content: 'Callback'));
        },
        width: 15,
        height: 3,
      );
      expect(result, equals('Callback'));
    });

    test('can render multiple widgets', () {
      final result = captureWith(
        (t) {
          // Render at different positions
          Paragraph(content: 'Line1').render(
            Rect.create(x: 0, y: 0, width: t.area.width, height: 1),
            t.frame,
          );
          Paragraph(content: 'Line2').render(
            Rect.create(x: 0, y: 1, width: t.area.width, height: 1),
            t.frame,
          );
        },
        width: 10,
        height: 2,
      );
      expect(result, equals('Line1\nLine2'));
    });
  });

  group('CaptureBuilder', () {
    test('async setup', () async {
      final result = await CaptureBuilder(width: 10, height: 1).setup((t) async {
        await Future<void>.delayed(Duration.zero);
        t.render(Paragraph(content: 'Async'));
      }).capture();

      expect(result, equals('Async'));
    });

    test('captureResult returns metadata', () async {
      final result = await CaptureBuilder(width: 20, height: 5).setup((t) {
        t.render(Paragraph(content: 'Meta'));
      }).captureResult();

      expect(result.content, equals('Meta'));
      expect(result.width, equals(20));
      expect(result.height, equals(5));
    });
  });

  group('WidgetTester', () {
    test('uses default dimensions', () {
      final tester = WidgetTester(defaultWidth: 30, defaultHeight: 10);
      final result = tester.captureResult(Paragraph(content: 'Test'));

      expect(result.width, equals(30));
      expect(result.height, equals(10));
    });

    test('overrides defaults per-capture', () {
      final tester = WidgetTester(defaultWidth: 30, defaultHeight: 10);
      final result = tester.captureResult(
        Paragraph(content: 'Test'),
        width: 5,
        height: 2,
      );

      expect(result.width, equals(5));
      expect(result.height, equals(2));
    });

    test('custom empty cell marker', () {
      final tester = WidgetTester(emptyCellMarker: '_');
      final result = tester.capture(
        Paragraph(content: 'X'),
        width: 3,
        height: 1,
        showEmptyCells: true,
      );
      // Markers aren't trimmed (not whitespace)
      expect(result, equals('X__'));
    });

    test('async capture', () async {
      final tester = WidgetTester(defaultWidth: 10, defaultHeight: 1);
      final result = await tester.captureAsync((t) async {
        await Future<void>.delayed(Duration.zero);
        t.render(Paragraph(content: 'Async'));
      });
      expect(result, equals('Async'));
    });
  });

  group('rendersAs matcher', () {
    test('matches correct output', () {
      final p = Paragraph(content: 'Hello');
      expect(p, rendersAs('Hello', width: 10, height: 1));
    });

    test('handles multiline expected with Dart string quirks', () {
      final p = Paragraph(content: 'A\nB');
      expect(
        p,
        rendersAs(
          '''
A
B
''',
          width: 5,
          height: 2,
        ),
      );
    });

    test('fails on mismatch', () {
      final p = Paragraph(content: 'Hello');
      expect(
        () => expect(p, rendersAs('World', width: 10, height: 1)),
        throwsA(isA<TestFailure>()),
      );
    });

    test('with border option', () {
      final p = Paragraph(content: 'X');
      expect(
        p,
        rendersAs(
          '''
+---+
|X  |
+---+
''',
          width: 3,
          height: 1,
          showBorder: true,
        ),
      );
    });
  });

  group('normalizeExpected', () {
    test('strips leading newline', () {
      final result = normalizeExpected('\nHello', CaptureConfig.defaults);
      expect(result, equals('Hello'));
    });

    test('strips trailing newline', () {
      final result = normalizeExpected('Hello\n', CaptureConfig.defaults);
      expect(result, equals('Hello'));
    });

    test('handles both', () {
      final result = normalizeExpected('\nHello\n', CaptureConfig.defaults);
      expect(result, equals('Hello'));
    });

    test('trims trailing whitespace per line', () {
      final result = normalizeExpected('Hello   \nWorld  ', CaptureConfig.defaults);
      expect(result, equals('Hello\nWorld'));
    });
  });
}
