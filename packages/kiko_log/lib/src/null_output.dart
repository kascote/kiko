import 'log_output.dart';
import 'log_record.dart';

/// A no-op output that discards all records.
class NullOutput implements LogOutput {
  /// Creates a null output.
  const NullOutput();

  @override
  void write(LogRecord record) {}

  @override
  Future<void> close() async {}
}
