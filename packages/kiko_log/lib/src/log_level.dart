/// Log severity levels ordered from most to least severe.
enum LogLevel {
  /// App cannot continue.
  fatal,

  /// Failures, exceptions.
  error,

  /// Potential issues.
  warn,

  /// Significant events.
  info,

  /// Detailed flow.
  debug,

  /// Everything.
  trace,
}
