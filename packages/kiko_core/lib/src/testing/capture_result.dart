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
