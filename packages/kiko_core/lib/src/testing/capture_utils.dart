import '../buffer.dart';
import 'capture_config.dart';

/// Convert a buffer to a string representation.
String bufferToString(Buffer buffer, CaptureConfig config) {
  final lines = <String>[];
  final area = buffer.area;

  for (var y = 0; y < area.height; y++) {
    final sb = StringBuffer();
    for (var x = 0; x < area.width; x++) {
      final cell = buffer[(x: area.x + x, y: area.y + y)];
      if (cell.skip) continue;

      final symbol = cell.symbol;
      if (config.showEmptyCells && symbol == ' ') {
        sb.write(config.emptyCellMarker);
      } else {
        sb.write(symbol);
      }
    }

    var line = sb.toString();
    if (config.trimTrailingWhitespace) {
      line = line.trimRight();
    }
    lines.add(line);
  }

  var result = lines.join('\n');

  if (config.stripBlankLines) {
    result = _stripSurroundingBlankLines(result);
  }

  return result;
}

/// Add debug border around content.
String addDebugBorder(String content, int width, int height) {
  final lines = content.split('\n');
  // Top border
  final bordered = <String>['+${'-' * width}+'];

  // Content lines with side borders
  for (var i = 0; i < height; i++) {
    final line = i < lines.length ? lines[i] : '';
    final padded = line.padRight(width);
    bordered.add('|$padded|');
  }

  // Bottom border
  bordered.add('+${'-' * width}+');

  return bordered.join('\n');
}

/// Strip leading and trailing blank lines from a string.
String _stripSurroundingBlankLines(String s) {
  final lines = s.split('\n');

  // Find first non-blank line
  var start = 0;
  while (start < lines.length && lines[start].trim().isEmpty) {
    start++;
  }

  // Find last non-blank line
  var end = lines.length - 1;
  while (end >= start && lines[end].trim().isEmpty) {
    end--;
  }

  if (start > end) return '';

  return lines.sublist(start, end + 1).join('\n');
}

/// Normalize expected string for comparison.
///
/// Handles Dart multiline string quirks and applies whitespace normalization.
String normalizeExpected(String expected, CaptureConfig config) {
  var result = expected;

  // Handle Dart multiline string leading newline after '''
  if (result.startsWith('\n')) {
    result = result.substring(1);
  }

  // Handle trailing newline before closing '''
  if (result.endsWith('\n')) {
    result = result.substring(0, result.length - 1);
  }

  if (config.trimTrailingWhitespace) {
    final lines = result.split('\n');
    result = lines.map((l) => l.trimRight()).join('\n');
  }

  if (config.stripBlankLines) {
    result = _stripSurroundingBlankLines(result);
  }

  return result;
}
