import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Cell', () {
    test('new', () {
      const cell = Cell(char: 'あ');
      expect(
        cell.toString(),
        'Cell(あ, fg: Color(Reset), bg: Color(Reset), underline: Color(Reset), modifier: Modifier(NONE), skip: false)',
      );
    });

    test('empty', () {
      final cell = Cell.empty();
      expect(cell.symbol, ' ');
      expect(
        cell.toString(),
        'Cell( , fg: Color(Reset), bg: Color(Reset), underline: Color(Reset), modifier: Modifier(NONE), skip: false)',
      );
    });

    test('setSymbol', () {
      final cell = const Cell(char: 'あ').copyWith(char: 'い');
      expect(cell.symbol, 'い');
      expect(
        cell.toString(),
        'Cell(い, fg: Color(Reset), bg: Color(Reset), underline: Color(Reset), modifier: Modifier(NONE), skip: false)',
      );

      // Multiple code units combined with ZWJ
      final c2 = cell.copyWith(char: '👨‍👩‍👧‍👦');
      expect(
        c2.toString(),
        'Cell(👨‍👩‍👧‍👦, fg: Color(Reset), bg: Color(Reset), underline: Color(Reset), modifier: Modifier(NONE), skip: false)',
      );
    });

    test('copyWith', () {
      const cell = Cell(char: 'あ');
      final cell2 = cell.copyWith(
        fg: Color.red,
        bg: Color.green,
        underline: Color.blue,
        modifier: Modifier.bold | Modifier.italic,
        skip: true,
      );
      expect(
        cell2.toString(),
        'Cell(あ, fg: Color(1, ansi), bg: Color(2, ansi), underline: Color(4, ansi), modifier: Modifier(bold italic), skip: true)',
      );
    });

    test('reset', () {
      final cell = Cell.empty()
          .copyWith(
            char: 'あ',
            fg: Color.red,
            bg: Color.green,
            underline: Color.blue,
            modifier: Modifier.bold | Modifier.italic,
            skip: true,
          )
          .reset();

      expect(
        cell.toString(),
        'Cell( , fg: Color(Reset), bg: Color(Reset), underline: Color(Reset), modifier: Modifier(NONE), skip: false)',
      );
    });

    test('style', () {
      final cell = Cell.empty();
      expect(
        cell.style().toString(),
        'Style(fg: Color(Reset), bg: Color(Reset), underline: Color(Reset), addModifier: Modifier(NONE), subModifier: Modifier(NONE))',
      );
    });

    test('equality', () {
      const cell1 = Cell(char: 'あ');
      const cell2 = Cell(char: 'あ');

      expect(cell1 == cell2, true);
    });

    group('setCell skip flag handling', () {
      test('setCell clears skip flag', () {
        // This is critical: when overwriting a skip cell (used for wide char
        // overflow), the skip flag must be cleared so the cell appears in
        // buffer diff and gets rendered to terminal.
        const skipCell = Cell(char: ' ', skip: true);
        final result = skipCell.setCell(char: 'a');

        expect(result.symbol, 'a');
        expect(result.skip, false, reason: 'setCell must clear skip flag');
      });

      test('setCell on normal cell keeps skip false', () {
        const normalCell = Cell(char: 'x');
        final result = normalCell.setCell(char: 'y');

        expect(result.symbol, 'y');
        expect(result.skip, false);
      });

      test('setCell with style clears skip flag', () {
        const skipCell = Cell(char: ' ', skip: true);
        final result = skipCell.setCell(
          char: 'b',
          style: const Style(fg: Color.red),
        );

        expect(result.symbol, 'b');
        expect(result.fg, Color.red);
        expect(result.skip, false, reason: 'setCell must clear skip flag');
      });
    });
  });
}
