import 'log_record.dart';

/// Abstract output destination for log records.
abstract class LogOutput {
  /// Writes a log record to the output.
  void write(LogRecord record);

  /// Closes the output, flushing any pending data.
  Future<void> close();
}
