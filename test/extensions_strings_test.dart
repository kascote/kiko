import 'package:kiko/iterators.dart';
import 'package:test/test.dart';

void main() {
  group('StringUtil', () {
    group('lines', () {
      test(r'splits string with only \n', () {
        const str = 'line1\nline2';
        final result = str.lines();
        expect(result, ['line1', 'line2']);
      });

      test(r'does not split string with only \r', () {
        const str = 'line1\rline2';
        final result = str.lines();
        expect(result, ['line1\rline2']);
      });

      test(r'splits string with \n\r', () {
        const str = 'line1\n\rline2';
        final result = str.lines();
        expect(result, ['line1', 'line2']);
      });

      test(r'splits string with \r\n', () {
        const str = 'line1\r\nline2';
        final result = str.lines();
        expect(result, ['line1\r', 'line2']);
      });

      test('splits string with multiple lines', () {
        const str = 'line1\nline2\nline3';
        final result = str.lines();
        expect(result, ['line1', 'line2', 'line3']);
      });

      test('returns empty list for empty string', () {
        const str = '';
        final result = str.lines();
        expect(result, ['']);
      });

      test('returns single element list for string with no line breaks', () {
        const str = 'line1 word2 word3';
        final result = str.lines();
        expect(result, ['line1 word2 word3']);
      });
    });
  });
}
