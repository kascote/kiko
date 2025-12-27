import 'dart:async';
import 'dart:io';

import 'log_formatter.dart';
import 'log_level.dart';
import 'log_output.dart';
import 'log_record.dart';

/// Writes log records to a file.
class FileOutput implements LogOutput {
  /// Creates a file output.
  ///
  /// [path] is the file path to write to.
  /// [formatter] defaults to [LogFormatter.standard].
  /// [flushPerWrite] if true, flushes after every write. Default false (buffered).
  FileOutput(
    this.path, {
    LogFormatter? formatter,
    this.flushPerWrite = false,
  }) : formatter = formatter ?? LogFormatter.standard,
       _sink = File(path).openWrite(mode: FileMode.append);

  /// The file path.
  final String path;

  /// The formatter to use.
  final LogFormatter formatter;

  /// Whether to flush after every write.
  final bool flushPerWrite;

  final IOSink _sink;

  @override
  void write(LogRecord record) {
    _sink.writeln(formatter.format(record));
    // Auto-flush on fatal/error or if configured
    if (flushPerWrite || record.level.index <= LogLevel.error.index) {
      unawaited(_sink.flush());
    }
  }

  @override
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
