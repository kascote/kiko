import 'dart:async';

import '../buffer.dart';
import '../layout/rect.dart';
import '../widgets/frame.dart';
import 'capture_config.dart';
import 'capture_result.dart';
import 'capture_tester.dart';
import 'capture_utils.dart';

/// Builder for capturing widget renders with async setup support.
///
/// Example:
/// ```dart
/// final result = await CaptureBuilder(width: 40, height: 10)
///   .setup((t) async {
///     final model = TreeViewModel(dataSource: source);
///     await model.loadRoots();
///     t.render(TreeView(model: model));
///   })
///   .capture();
/// ```
class CaptureBuilder {
  final int _width;
  final int _height;
  final CaptureConfig _config;
  FutureOr<void> Function(CaptureTester)? _setupFn;

  /// Creates a new [CaptureBuilder] with the given dimensions.
  CaptureBuilder({
    required int width,
    required int height,
    bool showBorder = false,
    bool showEmptyCells = false,
    String emptyCellMarker = '·',
    bool trimTrailingWhitespace = true,
    bool stripBlankLines = true,
  }) : _width = width,
       _height = height,
       _config = CaptureConfig(
         showBorder: showBorder,
         showEmptyCells: showEmptyCells,
         emptyCellMarker: emptyCellMarker,
         trimTrailingWhitespace: trimTrailingWhitespace,
         stripBlankLines: stripBlankLines,
       );

  /// Set up the capture with an async callback.
  ///
  /// The callback receives a [CaptureTester] for rendering widgets.
  CaptureBuilder setup(FutureOr<void> Function(CaptureTester) fn) {
    _setupFn = fn;
    // Builder pattern - chaining is intentional.
    // ignore: avoid_returning_this
    return this;
  }

  /// Execute the capture and return the string result.
  Future<String> capture() async {
    final result = await captureResult();
    return result.content;
  }

  /// Execute the capture and return a [CaptureResult] with metadata.
  Future<CaptureResult> captureResult() async {
    final area = Rect.create(x: 0, y: 0, width: _width, height: _height);
    final buffer = Buffer.empty(area);
    final frame = Frame(area, buffer, 0);
    final tester = CaptureTester(area: area, frame: frame);

    if (_setupFn != null) {
      await _setupFn!(tester);
    }

    var content = bufferToString(buffer, _config);

    if (_config.showBorder) {
      content = addDebugBorder(content, _width, _height);
    }

    return CaptureResult(
      content: content,
      width: _width,
      height: _height,
    );
  }
}
