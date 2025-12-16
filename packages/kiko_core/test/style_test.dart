import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Style', () {
    test('default constructor', () {
      const style = Style();

      expect(style.fg, isNull);
      expect(style.bg, isNull);
      expect(style.underline, isNull);
      expect(style.addModifier, Modifier.empty);
      expect(style.subModifier, Modifier.empty);
    });

    test('Constructor creates Style with correct properties', () {
      const style = Style(
        fg: Color.red,
        bg: Color.blue,
        underline: Color.green,
      );

      expect(style.fg, equals(Color.red));
      expect(style.bg, equals(Color.blue));
      expect(style.underline, equals(Color.green));
    });

    test('reset() creates Style with reset colors', () {
      const style = Style.reset();

      expect(style.fg, equals(Color.reset));
      expect(style.bg, equals(Color.reset));
      expect(style.underline, equals(Color.reset));
      expect(style.addModifier, Modifier.empty);
      expect(style.subModifier, Modifier.all);
    });

    test('addModifier() adds modifier correctly', () {
      final style = const Style().incModifier(Modifier.bold);
      final newStyle = style.incModifier(Modifier.italic);

      expect(newStyle, isNot(equals(style)));
      expect(
        newStyle.toString(),
        contains('addModifier: Modifier(bold italic)'),
      );
    });

    test('removeModifier() removes modifier correctly', () {
      final style = const Style().incModifier(Modifier.bold | Modifier.italic).removeModifier(Modifier.bold);

      expect(style.toString(), contains('addModifier: Modifier(italic)'));
      expect(style.toString(), contains('subModifier: Modifier(bold)'));
    });

    test('patch() combines two Styles correctly', () {
      final style1 = const Style(fg: Color.red).incModifier(Modifier.bold);
      final style2 = const Style(bg: Color.blue).incModifier(Modifier.italic);

      final patchedStyle = style1.patch(style2);

      expect(patchedStyle.fg, equals(Color.red));
      expect(patchedStyle.bg, equals(Color.blue));
      expect(
        patchedStyle.toString(),
        contains('addModifier: Modifier(bold italic)'),
      );

      // do not modify original styles
      expect(style1.fg, equals(Color.red));
      expect(style1.bg, isNull);
      expect(style1.addModifier, equals(Modifier.bold));
      expect(style2.bg, equals(Color.blue));
      expect(style2.fg, isNull);
      expect(style2.addModifier, equals(Modifier.italic));
    });

    test('patch() combines two Styles correctly', () {
      final style1 = const Style(fg: Color.red).incModifier(Modifier.bold);
      final style2 = const Style().incModifier(Modifier.italic);

      final patchedStyle = style1.patch(style2);

      expect(patchedStyle.fg, Color.red);
      expect(patchedStyle.bg, isNull);
      expect(
        patchedStyle.toString(),
        contains('addModifier: Modifier(bold italic)'),
      );

      // do not modify original styles
      expect(style1.fg, equals(Color.red));
      expect(style1.bg, isNull);
      expect(style1.addModifier, equals(Modifier.bold));
      expect(style2.fg, isNull);
      expect(style2.bg, isNull);
      expect(style2.addModifier, equals(Modifier.italic));
    });

    test('creates Style with foreground color', () {
      const style = Style(fg: Color.red);

      expect(style.fg, equals(Color.red));
      expect(style.bg, isNull);
      expect(style.underline, isNull);
    });

    test('creates Style with foreground and background colors', () {
      const style = Style(fg: Color.red, bg: Color.blue);

      expect(style.fg, equals(Color.red));
      expect(style.bg, equals(Color.blue));
      expect(style.underline, isNull);
    });

    test('creates Style with specified modifier', () {
      const style = Style(addModifier: Modifier.bold);

      expect(style.toString(), contains('addModifier: Modifier(bold)'));
    });

    test('creates Style with add and sub modifiers', () {
      final style = Style(subModifier: Modifier.bold | Modifier.italic);

      expect(style.toString(), contains('addModifier: Modifier(NONE)'));
      expect(style.toString(), contains('subModifier: Modifier(bold italic)'));
    });

    test('creates Style with foreground color and modifier', () {
      const style = Style(fg: Color.red, addModifier: Modifier.bold);

      expect(style.fg, equals(Color.red));
      expect(style.toString(), contains('addModifier: Modifier(bold)'));
    });

    test('creates Style with colors and modifier', () {
      const style = Style(
        fg: Color.red,
        bg: Color.blue,
        addModifier: Modifier.bold,
      );

      expect(style.fg, equals(Color.red));
      expect(style.bg, equals(Color.blue));
      expect(style.toString(), contains('addModifier: Modifier(bold)'));
    });

    test('creates Style with colors and modifiers', () {
      const style = Style(
        fg: Color.red,
        bg: Color.blue,
        addModifier: Modifier.bold,
        subModifier: Modifier.italic,
      );

      expect(style.fg, equals(Color.red));
      expect(style.bg, equals(Color.blue));
      expect(style.toString(), contains('addModifier: Modifier(bold)'));
      expect(style.toString(), contains('subModifier: Modifier(italic)'));
    });

    test('copyWith() creates a new Style with specified changes', () {
      const original = Style(fg: Color.red, bg: Color.blue);
      final copied = original.copyWith(fg: Color.green);

      expect(copied.fg, equals(Color.green));
      expect(copied.bg, equals(Color.blue));
      expect(copied.underline, isNull);
    });

    test('copyWith() handles null values correctly', () {
      const original = Style(fg: Color.red, bg: Color.blue);
      final copied = original.copyWith(fg: null);

      expect(copied.fg, isNull);
      expect(copied.bg, equals(Color.blue));
    });

    test('toString() returns a correct string representation', () {
      final style = const Style(
        fg: Color.red,
        bg: Color.blue,
      ).incModifier(Modifier.bold);

      expect(
        style.toString(),
        contains(
          'Style(fg: Color(1, ansi), bg: Color(4, ansi), underline: null',
        ),
      );
      expect(style.toString(), contains('addModifier: Modifier(bold)'));
      expect(style.toString(), contains('subModifier: Modifier(NONE)'));
    });

    test('_getValueOrNull() handles edge cases correctly', () {
      const style = Style();

      expect(
        () => style.copyWith(fg: 'invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('_getValue() handles edge cases correctly', () {
      const style = Style();

      expect(
        () => style.copyWith(addModifier: 'invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('check CopyWith on incModifier', () {
      final style = const Style(
        fg: Color.red,
        bg: Color.blue,
      ).incModifier(Modifier.bold);
      final copied = style.copyWith(fg: Color.green);

      expect(copied.fg, equals(Color.green));
      expect(copied.bg, equals(Color.blue));
      expect(copied.toString(), contains('addModifier: Modifier(bold)'));
    });
  });

  group('Modifier >', () {
    test('operands &', () {
      expect(Modifier.all & Modifier.bold, Modifier.bold);
    });

    test('toString', () {
      expect(Modifier.all.toString(), 'Modifier(ALL)');
    });
  });
}
