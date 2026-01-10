import 'package:meta/meta.dart';

/// Result of capturing a widget render.
///
/// Contains the rendered string content and metadata about the capture.
@immutable
class CaptureResult {
  /// The rendered string content.
  final String content;

  /// Width of the capture area.
  final int width;

  /// Height of the capture area.
  final int height;

  /// Creates a new [CaptureResult].
  const CaptureResult({
    required this.content,
    required this.width,
    required this.height,
  });

  /// Content split by lines.
  List<String> get lines => content.split('\n');

  /// Number of lines in the content.
  int get lineCount => lines.length;

  /// Get a single line by index (0-based).
  ///
  /// Throws [RangeError] if index is out of bounds.
  String line(int index) => lines[index];

  /// Extract a rectangular region from the content.
  ///
  /// Returns the substring from each line within the specified bounds.
  /// - [x]: Starting column (0-based)
  /// - [y]: Starting row (0-based)
  /// - [width]: Number of columns to extract
  /// - [height]: Number of rows to extract
  ///
  /// Lines shorter than x+width are padded with spaces.
  /// Rows beyond content are returned as empty strings of [width].
  String region({
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    final result = <String>[];
    final contentLines = lines;
    for (var row = y; row < y + height; row++) {
      if (row < 0 || row >= contentLines.length) {
        result.add(' ' * width);
      } else {
        final line = contentLines[row];
        if (x >= line.length) {
          result.add(' ' * width);
        } else {
          final end = x + width;
          if (end <= line.length) {
            result.add(line.substring(x, end));
          } else {
            result.add(line.substring(x).padRight(width));
          }
        }
      }
    }
    return result.join('\n');
  }

  @override
  String toString() => content;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CaptureResult && other.content == content && other.width == width && other.height == height;
  }

  @override
  int get hashCode => Object.hash(content, width, height);
}
