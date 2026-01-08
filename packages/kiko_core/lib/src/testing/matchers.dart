import 'package:matcher/matcher.dart';

import '../buffer.dart';
import '../layout/rect.dart';
import '../widgets/frame.dart';
import 'capture_config.dart';
import 'capture_utils.dart';

/// Matcher that verifies a widget renders as the expected string.
///
/// Example:
/// ```dart
/// expect(myWidget, rendersAs('''
/// Hello
/// World
/// ''', width: 20, height: 2));
/// ```
Matcher rendersAs(
  String expected, {
  required int width,
  required int height,
  bool showBorder = false,
  bool showEmptyCells = false,
  String emptyCellMarker = '·',
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,
}) {
  return _RendersAsMatcher(
    expected: expected,
    width: width,
    height: height,
    config: CaptureConfig(
      showBorder: showBorder,
      showEmptyCells: showEmptyCells,
      emptyCellMarker: emptyCellMarker,
      trimTrailingWhitespace: trimTrailingWhitespace,
      stripBlankLines: stripBlankLines,
    ),
  );
}

class _RendersAsMatcher extends Matcher {
  final String expected;
  final int width;
  final int height;
  final CaptureConfig config;

  _RendersAsMatcher({
    required this.expected,
    required this.width,
    required this.height,
    required this.config,
  });

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! Widget) {
      matchState['error'] = 'Expected a Widget, got ${item.runtimeType}';
      return false;
    }

    final area = Rect.create(x: 0, y: 0, width: width, height: height);
    final buffer = Buffer.empty(area);
    final frame = Frame(area, buffer, 0);

    item.render(area, frame);

    var actual = bufferToString(buffer, config);
    if (config.showBorder) {
      actual = addDebugBorder(actual, width, height);
    }

    final normalizedExpected = normalizeExpected(expected, config);

    matchState['actual'] = actual;
    matchState['expected'] = normalizedExpected;

    return actual == normalizedExpected;
  }

  @override
  Description describe(Description description) {
    final normalizedExpected = normalizeExpected(expected, config);
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
