import 'dart:async';

import 'package:matcher/matcher.dart';

import '../buffer.dart';
import '../layout/rect.dart';
import '../widgets/frame.dart';
import 'capture_config.dart';
import 'capture_result.dart';
import 'capture_tester.dart';
import 'capture_utils.dart';

/// Configurable tester for widget captures.
///
/// Use when you need custom configuration for multiple captures:
/// ```dart
/// final tester = WidgetTester(
///   defaultWidth: 80,
///   defaultHeight: 24,
///   emptyCellMarker: '.',
/// );
///
/// expect(tester.capture(widget1), equals('...'));
/// expect(tester.capture(widget2), equals('...'));
/// ```
class WidgetTester {
  /// Default width for captures.
  final int defaultWidth;

  /// Default height for captures.
  final int defaultHeight;

  /// Base configuration.
  final CaptureConfig config;

  /// Creates a new [WidgetTester] with the given configuration.
  WidgetTester({
    this.defaultWidth = 80,
    this.defaultHeight = 24,
    String emptyCellMarker = '·',
    bool trimTrailingWhitespace = true,
    bool stripBlankLines = true,
    bool includeStyles = false,
  }) : config = CaptureConfig(
         emptyCellMarker: emptyCellMarker,
         trimTrailingWhitespace: trimTrailingWhitespace,
         stripBlankLines: stripBlankLines,
         includeStyles: includeStyles,
       );

  /// Capture a widget render to string.
  String capture(
    Widget widget, {
    int? width,
    int? height,
    bool showBorder = false,
    bool showEmptyCells = false,
  }) {
    return captureResult(
      widget,
      width: width,
      height: height,
      showBorder: showBorder,
      showEmptyCells: showEmptyCells,
    ).content;
  }

  /// Capture a widget render with metadata.
  CaptureResult captureResult(
    Widget widget, {
    int? width,
    int? height,
    bool showBorder = false,
    bool showEmptyCells = false,
  }) {
    final w = width ?? defaultWidth;
    final h = height ?? defaultHeight;
    final captureConfig = config.copyWith(
      showBorder: showBorder,
      showEmptyCells: showEmptyCells,
    );

    final area = Rect.create(x: 0, y: 0, width: w, height: h);
    final buffer = Buffer.empty(area);
    final frame = Frame(area, buffer, 0);

    widget.render(area, frame);

    var content = bufferToString(buffer, captureConfig);

    if (showBorder) {
      content = addDebugBorder(content, w, h);
    }

    return CaptureResult(content: content, width: w, height: h);
  }

  /// Capture with a callback for complex setup.
  String captureWith(
    void Function(CaptureTester) callback, {
    int? width,
    int? height,
    bool showBorder = false,
    bool showEmptyCells = false,
  }) {
    return captureWithResult(
      callback,
      width: width,
      height: height,
      showBorder: showBorder,
      showEmptyCells: showEmptyCells,
    ).content;
  }

  /// Capture with a callback and return metadata.
  CaptureResult captureWithResult(
    void Function(CaptureTester) callback, {
    int? width,
    int? height,
    bool showBorder = false,
    bool showEmptyCells = false,
  }) {
    final w = width ?? defaultWidth;
    final h = height ?? defaultHeight;
    final captureConfig = config.copyWith(
      showBorder: showBorder,
      showEmptyCells: showEmptyCells,
    );

    final area = Rect.create(x: 0, y: 0, width: w, height: h);
    final buffer = Buffer.empty(area);
    final frame = Frame(area, buffer, 0);
    final tester = CaptureTester(area: area, frame: frame);

    callback(tester);

    var content = bufferToString(buffer, captureConfig);

    if (showBorder) {
      content = addDebugBorder(content, w, h);
    }

    return CaptureResult(content: content, width: w, height: h);
  }

  /// Async capture with setup callback.
  Future<String> captureAsync(
    FutureOr<void> Function(CaptureTester) callback, {
    int? width,
    int? height,
    bool showBorder = false,
    bool showEmptyCells = false,
  }) async {
    final result = await captureAsyncResult(
      callback,
      width: width,
      height: height,
      showBorder: showBorder,
      showEmptyCells: showEmptyCells,
    );
    return result.content;
  }

  /// Async capture with setup callback returning metadata.
  Future<CaptureResult> captureAsyncResult(
    FutureOr<void> Function(CaptureTester) callback, {
    int? width,
    int? height,
    bool showBorder = false,
    bool showEmptyCells = false,
  }) async {
    final w = width ?? defaultWidth;
    final h = height ?? defaultHeight;
    final captureConfig = config.copyWith(
      showBorder: showBorder,
      showEmptyCells: showEmptyCells,
    );

    final area = Rect.create(x: 0, y: 0, width: w, height: h);
    final buffer = Buffer.empty(area);
    final frame = Frame(area, buffer, 0);
    final tester = CaptureTester(area: area, frame: frame);

    await callback(tester);

    var content = bufferToString(buffer, captureConfig);

    if (showBorder) {
      content = addDebugBorder(content, w, h);
    }

    return CaptureResult(content: content, width: w, height: h);
  }

  /// Create a matcher using this tester's configuration.
  Matcher rendersAs(
    String expected, {
    int? width,
    int? height,
    bool showBorder = false,
    bool showEmptyCells = false,
  }) {
    return _TesterRendersAsMatcher(
      tester: this,
      expected: expected,
      width: width ?? defaultWidth,
      height: height ?? defaultHeight,
      showBorder: showBorder,
      showEmptyCells: showEmptyCells,
    );
  }
}

class _TesterRendersAsMatcher extends Matcher {
  final WidgetTester tester;
  final String expected;
  final int width;
  final int height;
  final bool showBorder;
  final bool showEmptyCells;

  _TesterRendersAsMatcher({
    required this.tester,
    required this.expected,
    required this.width,
    required this.height,
    required this.showBorder,
    required this.showEmptyCells,
  });

  CaptureConfig get _config => tester.config.copyWith(
    showBorder: showBorder,
    showEmptyCells: showEmptyCells,
  );

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! Widget) {
      matchState['error'] = 'Expected a Widget, got ${item.runtimeType}';
      return false;
    }

    final result = tester.captureResult(
      item,
      width: width,
      height: height,
      showBorder: showBorder,
      showEmptyCells: showEmptyCells,
    );

    final normalizedExpected = normalizeExpected(expected, _config);

    matchState['actual'] = result.content;
    matchState['expected'] = normalizedExpected;

    return result.content == normalizedExpected;
  }

  @override
  Description describe(Description description) {
    final normalizedExpected = normalizeExpected(expected, _config);
    return description.add('renders as:\n$normalizedExpected');
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'] as String);
    }

    final actual = matchState['actual'] as String;
    final expected = matchState['expected'] as String;

    final actualLines = actual.split('\n');
    final expectedLines = expected.split('\n');

    final sb = StringBuffer()
      ..writeln('rendered differently:')
      ..writeln('Expected:');
    for (var i = 0; i < expectedLines.length; i++) {
      sb.writeln('  ${i + 1}: ${expectedLines[i]}');
    }

    sb.writeln('Actual:');
    for (var i = 0; i < actualLines.length; i++) {
      final marker = (i < expectedLines.length && actualLines[i] != expectedLines[i]) ? ' <- differs' : '';
      sb.writeln('  ${i + 1}: ${actualLines[i]}$marker');
    }

    return mismatchDescription.add(sb.toString());
  }
}
