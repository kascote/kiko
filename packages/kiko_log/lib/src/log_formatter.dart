import 'log_record.dart';

/// Formats log records into strings.
class LogFormatter {
  /// Creates a formatter with a custom format function.
  const LogFormatter(this.format);

  /// The format function.
  final String Function(LogRecord) format;

  /// Standard format: `[2025-01-15 10:30:45.123] [INFO ] message`
  ///
  /// Includes indentation for groups, error and stack trace if present.
  static final standard = LogFormatter((r) {
    final ts = r.timestamp.toIso8601String().replaceFirst('T', ' ');
    final level = r.level.name.toUpperCase().padRight(5);
    final scope = r.scope != null ? '${r.scope}: ' : '';
    final indent = '  ' * r.depth;
    final buf = StringBuffer('[$ts] [$level] $indent$scope${r.message}');
    if (r.error != null) buf.write('\n        Error: ${r.error}');
    if (r.stack != null) buf.write('\n${_indentStack(r.stack!)}');
    return buf.toString();
  });

  /// Compact format: `10:30:45.123 INFO  message`
  static final compact = LogFormatter((r) {
    final ts = r.timestamp.toIso8601String().split('T')[1];
    final level = r.level.name.toUpperCase().padRight(5);
    final scope = r.scope != null ? '${r.scope}: ' : '';
    final indent = '  ' * r.depth;
    final buf = StringBuffer('$ts $level $indent$scope${r.message}');
    if (r.error != null) buf.write('\n  Error: ${r.error}');
    if (r.stack != null) buf.write('\n${_indentStack(r.stack!, prefix: '  ')}');
    return buf.toString();
  });

  static String _indentStack(StackTrace stack, {String prefix = '        '}) {
    return stack.toString().split('\n').map((l) => '$prefix$l').join('\n');
  }
}
