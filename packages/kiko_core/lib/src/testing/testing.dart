// Widget testing infrastructure for kiko.
//
// Provides utilities for visual testing of widgets:
// - capture / captureResult - render widget to string
// - captureWith - render with callback for complex setup
// - CaptureBuilder - async setup support
// - WidgetTester - configurable tester
// - rendersAs - custom matcher for test framework

export 'capture.dart';
export 'capture_builder.dart';
export 'capture_config.dart';
export 'capture_result.dart';
export 'capture_tester.dart';
export 'capture_utils.dart' show normalizeExpected;
export 'matchers.dart';
export 'widget_tester.dart';
