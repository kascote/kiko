import '../buffer.dart';
import '../layout/rect.dart';
import '../widgets/frame.dart';
import 'capture_config.dart';
import 'capture_result.dart';
import 'capture_tester.dart';
import 'capture_utils.dart';

/// Render a widget to a string.
///
/// Example:
/// ```dart
/// expect(
///   capture(myWidget, width: 40, height: 5),
///   equals('Hello World'),
/// );
/// ```
String capture(
  Widget widget, {
  required int width,
  required int height,
  bool showBorder = false,
  bool showEmptyCells = false,
  String emptyCellMarker = defaultEmptyCellMarker,
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,
}) {
  final result = captureResult(
    widget,
    width: width,
    height: height,
    showBorder: showBorder,
    showEmptyCells: showEmptyCells,
    emptyCellMarker: emptyCellMarker,
    trimTrailingWhitespace: trimTrailingWhitespace,
    stripBlankLines: stripBlankLines,
  );
  return result.content;
}

/// Render a widget and return a [CaptureResult] with metadata.
///
/// Example:
/// ```dart
/// final result = captureResult(myWidget, width: 40, height: 5);
/// print(result.lines); // ['Hello', 'World']
/// print(result.width); // 40
/// ```
CaptureResult captureResult(
  Widget widget, {
  required int width,
  required int height,
  bool showBorder = false,
  bool showEmptyCells = false,
  String emptyCellMarker = defaultEmptyCellMarker,
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,
}) {
  final config = CaptureConfig(
    showBorder: showBorder,
    showEmptyCells: showEmptyCells,
    emptyCellMarker: emptyCellMarker,
    trimTrailingWhitespace: trimTrailingWhitespace,
    stripBlankLines: stripBlankLines,
  );

  final area = Rect.create(x: 0, y: 0, width: width, height: height);
  final buffer = Buffer.empty(area);
  final frame = Frame(area, buffer, 0);

  widget.render(area, frame);

  var content = bufferToString(buffer, config);

  if (showBorder) {
    content = addDebugBorder(content, width, height);
  }

  return CaptureResult(
    content: content,
    width: width,
    height: height,
  );
}

/// Render with a callback for complex setup.
///
/// Example:
/// ```dart
/// final result = captureWith(
///   (t) {
///     t.render(TreeView(model: model));
///   },
///   width: 40,
///   height: 10,
/// );
/// ```
String captureWith(
  void Function(CaptureTester) callback, {
  required int width,
  required int height,
  bool showBorder = false,
  bool showEmptyCells = false,
  String emptyCellMarker = defaultEmptyCellMarker,
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,
}) {
  final result = captureWithResult(
    callback,
    width: width,
    height: height,
    showBorder: showBorder,
    showEmptyCells: showEmptyCells,
    emptyCellMarker: emptyCellMarker,
    trimTrailingWhitespace: trimTrailingWhitespace,
    stripBlankLines: stripBlankLines,
  );
  return result.content;
}

/// Render with a callback and return a [CaptureResult].
CaptureResult captureWithResult(
  void Function(CaptureTester) callback, {
  required int width,
  required int height,
  bool showBorder = false,
  bool showEmptyCells = false,
  String emptyCellMarker = defaultEmptyCellMarker,
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,
}) {
  final config = CaptureConfig(
    showBorder: showBorder,
    showEmptyCells: showEmptyCells,
    emptyCellMarker: emptyCellMarker,
    trimTrailingWhitespace: trimTrailingWhitespace,
    stripBlankLines: stripBlankLines,
  );

  final area = Rect.create(x: 0, y: 0, width: width, height: height);
  final buffer = Buffer.empty(area);
  final frame = Frame(area, buffer, 0);
  final tester = CaptureTester(area: area, frame: frame);

  callback(tester);

  var content = bufferToString(buffer, config);

  if (showBorder) {
    content = addDebugBorder(content, width, height);
  }

  return CaptureResult(
    content: content,
    width: width,
    height: height,
  );
}
