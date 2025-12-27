import 'dart:async';

import 'log_level.dart';
import 'log_output.dart';
import 'log_record.dart';
import 'null_output.dart';

/// Zone key for logger storage.
const _logKey = #kiko.log;

/// Zone-based structured logger.
///
/// Use static methods for logging from anywhere in the app.
/// Use [Log.scoped] to create a logger with a scope prefix.
class Log {
  /// Creates a logger.
  Log({
    required this.output,
    this.level = LogLevel.info,
    this.scope,
  });

  /// The output destination.
  final LogOutput output;

  /// Minimum level to log.
  final LogLevel level;

  /// Optional scope prefix.
  final String? scope;

  // State for timers, groups, and counters
  final Map<String, DateTime> _timers = {};
  final Map<String, int> _counters = {};
  int _depth = 0;

  // Zone accessor
  static Log? get _current => Zone.current[_logKey] as Log?;

  // Static convenience methods (use zone logger)

  /// Logs a fatal message. App cannot continue.
  static void fatal(String msg, [Object? error, StackTrace? stack]) =>
      _current?._logWithError(LogLevel.fatal, msg, error, stack);

  /// Logs an error message.
  static void error(String msg, [Object? error, StackTrace? stack]) =>
      _current?._logWithError(LogLevel.error, msg, error, stack);

  /// Logs a warning message.
  static void warn(String msg, [Object? error, StackTrace? stack]) =>
      _current?._logWithError(LogLevel.warn, msg, error, stack);

  /// Logs an info message.
  static void info(String msg) => _current?._log(LogLevel.info, msg);

  /// Logs a debug message.
  static void debug(String msg) => _current?._log(LogLevel.debug, msg);

  /// Logs a trace message.
  static void trace(String msg) => _current?._log(LogLevel.trace, msg);

  // Lazy eval methods (avoid string building if level disabled)

  /// Logs a fatal message with lazy evaluation.
  static void fatalLazy(String Function() msg) => _current?._logLazy(LogLevel.fatal, msg);

  /// Logs an error message with lazy evaluation.
  static void errorLazy(String Function() msg) => _current?._logLazy(LogLevel.error, msg);

  /// Logs a warning message with lazy evaluation.
  static void warnLazy(String Function() msg) => _current?._logLazy(LogLevel.warn, msg);

  /// Logs an info message with lazy evaluation.
  static void infoLazy(String Function() msg) => _current?._logLazy(LogLevel.info, msg);

  /// Logs a debug message with lazy evaluation.
  static void debugLazy(String Function() msg) => _current?._logLazy(LogLevel.debug, msg);

  /// Logs a trace message with lazy evaluation.
  static void traceLazy(String Function() msg) => _current?._logLazy(LogLevel.trace, msg);

  // Timer methods (Chrome DevTools style)

  /// Starts a timer with the given label.
  static void time(String label) => _current?._timeStart(label);

  /// Ends a timer and logs the elapsed time.
  static void timeEnd(String label) => _current?._timeEnd(label);

  // Group methods (Chrome DevTools style)

  /// Starts a new log group.
  static void group(String label) => _current?._groupStart(label);

  /// Ends the current log group.
  static void groupEnd([String? label]) => _current?._groupEnd(label);

  // Counter methods (Chrome DevTools style)

  /// Increments and logs a counter.
  static void count(String label) => _current?._count(label);

  /// Resets a counter to zero.
  static void countReset(String label) => _current?._countReset(label);

  /// Logs a warning if condition is false.
  // ignore: avoid_positional_boolean_parameters
  static void assert_(bool condition, String msg) {
    if (!condition) _current?._log(LogLevel.warn, 'Assertion failed: $msg');
  }

  /// Creates a scoped logger that shares state with the zone logger.
  static Log scoped(String name) {
    final current = _current;
    if (current == null) return Log(output: const NullOutput(), scope: name);
    return _ScopedLog(current, name);
  }

  /// Runs [body] with this logger in the zone.
  R runZoned<R>(R Function() body) {
    return runZonedGuarded(
          body,
          (error, stack) {
            _logWithError(LogLevel.error, 'Uncaught error', error, stack);
          },
          zoneValues: {_logKey: this},
        )
        as R;
  }

  void _log(LogLevel lvl, String msg) {
    if (lvl.index > level.index) return;
    output.write(
      LogRecord(
        timestamp: DateTime.now(),
        level: lvl,
        scope: scope,
        message: msg,
        depth: _depth,
      ),
    );
  }

  void _logWithError(LogLevel lvl, String msg, Object? error, StackTrace? stack) {
    if (lvl.index > level.index) return;
    output.write(
      LogRecord(
        timestamp: DateTime.now(),
        level: lvl,
        scope: scope,
        message: msg,
        depth: _depth,
        error: error,
        stack: stack,
      ),
    );
  }

  void _logLazy(LogLevel lvl, String Function() msg) {
    if (lvl.index > level.index) return; // skip callback if filtered
    _log(lvl, msg());
  }

  void _count(String label) {
    final count = (_counters[label] ?? 0) + 1;
    _counters[label] = count;
    _log(LogLevel.debug, '$label: $count');
  }

  void _countReset(String label) {
    _counters.remove(label);
  }

  void _timeStart(String label) {
    _timers[label] = DateTime.now();
  }

  void _timeEnd(String label) {
    final start = _timers.remove(label);
    if (start == null) {
      _log(LogLevel.warn, 'Timer "$label" not found');
      return;
    }
    final elapsed = DateTime.now().difference(start);
    _log(LogLevel.debug, '$label: ${_formatDuration(elapsed)}');
  }

  void _groupStart(String label) {
    _log(LogLevel.info, '▶ $label');
    _depth++;
  }

  void _groupEnd([String? label]) {
    if (_depth <= 0) {
      _log(LogLevel.warn, 'groupEnd without matching group');
      return;
    }
    _depth--;
    if (label != null) {
      _log(LogLevel.info, '◀ $label');
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    if (d.inSeconds < 60) return '${(d.inMilliseconds / 1000).toStringAsFixed(2)}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }

  // Instance methods (for scoped loggers)

  /// Logs a fatal message on this instance.
  void logFatal(String msg, [Object? error, StackTrace? stack]) => _logWithError(LogLevel.fatal, msg, error, stack);

  /// Logs an error message on this instance.
  void logError(String msg, [Object? error, StackTrace? stack]) => _logWithError(LogLevel.error, msg, error, stack);

  /// Logs a warning message on this instance.
  void logWarn(String msg, [Object? error, StackTrace? stack]) => _logWithError(LogLevel.warn, msg, error, stack);

  /// Logs an info message on this instance.
  void logInfo(String msg) => _log(LogLevel.info, msg);

  /// Logs a debug message on this instance.
  void logDebug(String msg) => _log(LogLevel.debug, msg);

  /// Logs a trace message on this instance.
  void logTrace(String msg) => _log(LogLevel.trace, msg);

  // Lazy instance methods

  /// Logs a fatal message with lazy evaluation on this instance.
  void logFatalLazy(String Function() msg) => _logLazy(LogLevel.fatal, msg);

  /// Logs an error message with lazy evaluation on this instance.
  void logErrorLazy(String Function() msg) => _logLazy(LogLevel.error, msg);

  /// Logs a warning message with lazy evaluation on this instance.
  void logWarnLazy(String Function() msg) => _logLazy(LogLevel.warn, msg);

  /// Logs an info message with lazy evaluation on this instance.
  void logInfoLazy(String Function() msg) => _logLazy(LogLevel.info, msg);

  /// Logs a debug message with lazy evaluation on this instance.
  void logDebugLazy(String Function() msg) => _logLazy(LogLevel.debug, msg);

  /// Logs a trace message with lazy evaluation on this instance.
  void logTraceLazy(String Function() msg) => _logLazy(LogLevel.trace, msg);
}

/// Scoped logger that shares state with parent (composition).
class _ScopedLog implements Log {
  _ScopedLog(this._parent, this.scope);

  final Log _parent;

  @override
  final String? scope;

  @override
  LogOutput get output => _parent.output;

  @override
  LogLevel get level => _parent.level;

  // Delegate all state to parent
  @override
  int get _depth => _parent._depth;
  @override
  set _depth(int v) => _parent._depth = v;
  @override
  Map<String, DateTime> get _timers => _parent._timers;
  @override
  Map<String, int> get _counters => _parent._counters;

  // Delegate internal methods - need to override to use this.scope
  @override
  void _log(LogLevel lvl, String msg) {
    if (lvl.index > level.index) return;
    output.write(
      LogRecord(
        timestamp: DateTime.now(),
        level: lvl,
        scope: scope,
        message: msg,
        depth: _depth,
      ),
    );
  }

  @override
  void _logWithError(LogLevel lvl, String msg, Object? error, StackTrace? stack) {
    if (lvl.index > level.index) return;
    output.write(
      LogRecord(
        timestamp: DateTime.now(),
        level: lvl,
        scope: scope,
        message: msg,
        depth: _depth,
        error: error,
        stack: stack,
      ),
    );
  }

  @override
  void _logLazy(LogLevel lvl, String Function() msg) {
    if (lvl.index > level.index) return;
    _log(lvl, msg());
  }

  @override
  void _count(String label) => _parent._count(label);
  @override
  void _countReset(String label) => _parent._countReset(label);
  @override
  void _timeStart(String label) => _parent._timeStart(label);
  @override
  void _timeEnd(String label) => _parent._timeEnd(label);
  @override
  void _groupStart(String label) => _parent._groupStart(label);
  @override
  void _groupEnd([String? label]) => _parent._groupEnd(label);
  @override
  String _formatDuration(Duration d) => _parent._formatDuration(d);
  @override
  R runZoned<R>(R Function() body) => _parent.runZoned(body);

  // Instance methods
  @override
  void logFatal(String msg, [Object? error, StackTrace? stack]) => _logWithError(LogLevel.fatal, msg, error, stack);
  @override
  void logError(String msg, [Object? error, StackTrace? stack]) => _logWithError(LogLevel.error, msg, error, stack);
  @override
  void logWarn(String msg, [Object? error, StackTrace? stack]) => _logWithError(LogLevel.warn, msg, error, stack);
  @override
  void logInfo(String msg) => _log(LogLevel.info, msg);
  @override
  void logDebug(String msg) => _log(LogLevel.debug, msg);
  @override
  void logTrace(String msg) => _log(LogLevel.trace, msg);

  @override
  void logFatalLazy(String Function() msg) => _logLazy(LogLevel.fatal, msg);
  @override
  void logErrorLazy(String Function() msg) => _logLazy(LogLevel.error, msg);
  @override
  void logWarnLazy(String Function() msg) => _logLazy(LogLevel.warn, msg);
  @override
  void logInfoLazy(String Function() msg) => _logLazy(LogLevel.info, msg);
  @override
  void logDebugLazy(String Function() msg) => _logLazy(LogLevel.debug, msg);
  @override
  void logTraceLazy(String Function() msg) => _logLazy(LogLevel.trace, msg);
}
