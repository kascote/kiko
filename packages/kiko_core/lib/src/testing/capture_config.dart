/// Default marker character for empty cells.
const defaultEmptyCellMarker = '·';

/// Configuration for capture operations.
class CaptureConfig {
  /// Whether to show a debug border around the widget area.
  final bool showBorder;

  /// Whether to show empty cells with a visible marker.
  final bool showEmptyCells;

  /// The marker character for empty cells.
  final String emptyCellMarker;

  /// Whether to trim trailing whitespace from each line.
  final bool trimTrailingWhitespace;

  /// Whether to strip leading/trailing blank lines.
  final bool stripBlankLines;

  /// Whether to include style information.
  final bool includeStyles;

  /// Default configuration.
  static const CaptureConfig defaults = CaptureConfig();

  /// Creates a new [CaptureConfig].
  const CaptureConfig({
    this.showBorder = false,
    this.showEmptyCells = false,
    this.emptyCellMarker = defaultEmptyCellMarker,
    this.trimTrailingWhitespace = true,
    this.stripBlankLines = true,
    this.includeStyles = false,
  });

  /// Create a copy with updated values.
  CaptureConfig copyWith({
    bool? showBorder,
    bool? showEmptyCells,
    String? emptyCellMarker,
    bool? trimTrailingWhitespace,
    bool? stripBlankLines,
    bool? includeStyles,
  }) {
    return CaptureConfig(
      showBorder: showBorder ?? this.showBorder,
      showEmptyCells: showEmptyCells ?? this.showEmptyCells,
      emptyCellMarker: emptyCellMarker ?? this.emptyCellMarker,
      trimTrailingWhitespace: trimTrailingWhitespace ?? this.trimTrailingWhitespace,
      stripBlankLines: stripBlankLines ?? this.stripBlankLines,
      includeStyles: includeStyles ?? this.includeStyles,
    );
  }
}
