import 'log_level.dart';

/// A single log entry.
class LogRecord {
  /// Creates a log record.
  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
    this.scope,
    this.depth = 0,
    this.error,
    this.stack,
  });

  /// When the log was created.
  final DateTime timestamp;

  /// Severity level.
  final LogLevel level;

  /// Optional scope/category prefix.
  final String? scope;

  /// The log message.
  final String message;

  /// Group nesting depth for indentation.
  final int depth;

  /// Optional error object.
  final Object? error;

  /// Optional stack trace.
  final StackTrace? stack;
}
