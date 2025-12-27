import 'dart:async';
import 'dart:io';

import 'package:kiko_log/kiko_log.dart';
import 'package:test/test.dart';

/// In-memory output for testing.
class TestOutput implements LogOutput {
  final List<LogRecord> records = [];

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> close() async {}

  LogRecord get last => records.last;
  String get lastMessage => records.last.message;
  LogLevel get lastLevel => records.last.level;
}

void main() {
  group('LogLevel', () {
    test('ordering is fatal < error < warn < info < debug < trace', () {
      expect(LogLevel.fatal.index, lessThan(LogLevel.error.index));
      expect(LogLevel.error.index, lessThan(LogLevel.warn.index));
      expect(LogLevel.warn.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.debug.index));
      expect(LogLevel.debug.index, lessThan(LogLevel.trace.index));
    });
  });

  group('LogRecord', () {
    test('stores all fields', () {
      final ts = DateTime.now();
      final error = Exception('test');
      final stack = StackTrace.current;
      final record = LogRecord(
        timestamp: ts,
        level: LogLevel.error,
        scope: 'TestScope',
        message: 'test message',
        depth: 2,
        error: error,
        stack: stack,
      );

      expect(record.timestamp, ts);
      expect(record.level, LogLevel.error);
      expect(record.scope, 'TestScope');
      expect(record.message, 'test message');
      expect(record.depth, 2);
      expect(record.error, error);
      expect(record.stack, stack);
    });
  });

  group('LogFormatter', () {
    test('standard format includes timestamp, level, message', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 15, 10, 30, 45, 123),
        level: LogLevel.info,
        message: 'test message',
      );

      final formatted = LogFormatter.standard.format(record);
      expect(formatted, contains('2025-01-15 10:30:45.123'));
      expect(formatted, contains('[INFO ]'));
      expect(formatted, contains('test message'));
    });

    test('standard format includes scope', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 15, 10, 30, 45),
        level: LogLevel.info,
        scope: 'MyScope',
        message: 'test',
      );

      final formatted = LogFormatter.standard.format(record);
      expect(formatted, contains('MyScope: test'));
    });

    test('standard format includes indentation for depth', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 15, 10, 30, 45),
        level: LogLevel.info,
        message: 'nested',
        depth: 2,
      );

      final formatted = LogFormatter.standard.format(record);
      expect(formatted, contains('[INFO ]     nested')); // 4 spaces = 2 * 2
    });

    test('standard format includes error', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 15, 10, 30, 45),
        level: LogLevel.error,
        message: 'failed',
        error: const FormatException('bad format'),
      );

      final formatted = LogFormatter.standard.format(record);
      expect(formatted, contains('Error: FormatException: bad format'));
    });

    test('standard format includes stack trace', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 15, 10, 30, 45),
        level: LogLevel.error,
        message: 'failed',
        stack: StackTrace.current,
      );

      final formatted = LogFormatter.standard.format(record);
      expect(formatted, contains('#0'));
    });

    test('compact format uses time only', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 15, 10, 30, 45, 123),
        level: LogLevel.debug,
        message: 'compact test',
      );

      final formatted = LogFormatter.compact.format(record);
      expect(formatted, contains('10:30:45.123'));
      expect(formatted, isNot(contains('2025-01-15')));
      expect(formatted, contains('DEBUG'));
      expect(formatted, contains('compact test'));
    });
  });

  group('NullOutput', () {
    test('discards all records', () async {
      final output = const NullOutput()
        ..write(
          LogRecord(
            timestamp: DateTime(2025),
            level: LogLevel.info,
            message: 'test',
          ),
        );
      await output.close();
      // No exception means success
    });
  });

  group('Log', () {
    late TestOutput output;
    late Log log;

    setUp(() {
      output = TestOutput();
      log = Log(output: output, level: LogLevel.trace);
    });

    group('level filtering', () {
      test('filters messages below configured level', () {
        Log(output: output).runZoned(() {
          Log.debug('should be filtered');
          Log.trace('also filtered');
          Log.info('should appear');
        });

        expect(output.records.length, 1);
        expect(output.lastMessage, 'should appear');
      });

      test('allows messages at or above configured level', () {
        Log(output: output, level: LogLevel.warn).runZoned(() {
          Log.fatal('fatal');
          Log.error('error');
          Log.warn('warn');
        });

        expect(output.records.length, 3);
      });
    });

    group('static methods', () {
      test('fatal logs at fatal level', () {
        log.runZoned(() => Log.fatal('critical'));
        expect(output.lastLevel, LogLevel.fatal);
      });

      test('error logs at error level', () {
        log.runZoned(() => Log.error('failure'));
        expect(output.lastLevel, LogLevel.error);
      });

      test('warn logs at warn level', () {
        log.runZoned(() => Log.warn('warning'));
        expect(output.lastLevel, LogLevel.warn);
      });

      test('info logs at info level', () {
        log.runZoned(() => Log.info('information'));
        expect(output.lastLevel, LogLevel.info);
      });

      test('debug logs at debug level', () {
        log.runZoned(() => Log.debug('debugging'));
        expect(output.lastLevel, LogLevel.debug);
      });

      test('trace logs at trace level', () {
        log.runZoned(() => Log.trace('tracing'));
        expect(output.lastLevel, LogLevel.trace);
      });
    });

    group('error with stack', () {
      test('fatal includes error and stack', () {
        final error = Exception('fatal error');
        final stack = StackTrace.current;
        log.runZoned(() => Log.fatal('crashed', error, stack));

        expect(output.last.error, error);
        expect(output.last.stack, stack);
      });

      test('error includes error and stack', () {
        final error = Exception('test error');
        final stack = StackTrace.current;
        log.runZoned(() => Log.error('failed', error, stack));

        expect(output.last.error, error);
        expect(output.last.stack, stack);
      });

      test('warn includes error and stack', () {
        final error = Exception('potential issue');
        final stack = StackTrace.current;
        log.runZoned(() => Log.warn('warning', error, stack));

        expect(output.last.error, error);
        expect(output.last.stack, stack);
      });
    });

    group('lazy evaluation', () {
      test('callback invoked when level enabled', () {
        var called = false;
        log.runZoned(() {
          Log.debugLazy(() {
            called = true;
            return 'lazy debug';
          });
        });

        expect(called, isTrue);
        expect(output.lastMessage, 'lazy debug');
      });

      test('callback not invoked when level filtered', () {
        var called = false;
        Log(output: output).runZoned(() {
          Log.debugLazy(() {
            called = true;
            return 'should not appear';
          });
        });

        expect(called, isFalse);
        expect(output.records, isEmpty);
      });

      test('all lazy variants work', () {
        log.runZoned(() {
          Log.fatalLazy(() => 'lazy fatal');
          Log.errorLazy(() => 'lazy error');
          Log.warnLazy(() => 'lazy warn');
          Log.infoLazy(() => 'lazy info');
          Log.debugLazy(() => 'lazy debug');
          Log.traceLazy(() => 'lazy trace');
        });

        expect(output.records.length, 6);
      });
    });

    group('timers', () {
      test('timeEnd logs elapsed time', () async {
        await log.runZoned(() async {
          Log.time('test-timer');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          Log.timeEnd('test-timer');
        });

        final timerRecord = output.records.firstWhere(
          (r) => r.message.contains('test-timer:'),
        );
        expect(timerRecord.level, LogLevel.debug);
        expect(timerRecord.message, contains('ms'));
      });

      test('timeEnd warns on missing timer', () {
        log.runZoned(() => Log.timeEnd('nonexistent'));

        expect(output.lastLevel, LogLevel.warn);
        expect(output.lastMessage, contains('not found'));
      });
    });

    group('groups', () {
      test('group increases depth', () {
        log.runZoned(() {
          Log.group('outer');
          Log.info('nested message');
        });

        final nested = output.records.firstWhere((r) => r.message == 'nested message');
        expect(nested.depth, 1);
      });

      test('groupEnd decreases depth', () {
        log.runZoned(() {
          Log.group('test');
          Log.groupEnd();
          Log.info('after group');
        });

        final after = output.records.firstWhere((r) => r.message == 'after group');
        expect(after.depth, 0);
      });

      test('groupEnd with label logs closing marker', () {
        log.runZoned(() {
          Log.group('test');
          Log.groupEnd('test');
        });

        expect(output.records.any((r) => r.message.contains('◀ test')), isTrue);
      });

      test('nested groups work correctly', () {
        log.runZoned(() {
          Log.group('outer');
          Log.info('depth 1');
          Log.group('inner');
          Log.info('depth 2');
          Log.groupEnd();
          Log.info('back to 1');
          Log.groupEnd();
          Log.info('depth 0');
        });

        final depths = output.records
            .where((r) => r.message.startsWith('depth') || r.message.startsWith('back'))
            .map((r) => r.depth)
            .toList();
        expect(depths, [1, 2, 1, 0]);
      });

      test('orphan groupEnd warns', () {
        log.runZoned(Log.groupEnd);

        expect(output.lastLevel, LogLevel.warn);
        expect(output.lastMessage, contains('without matching group'));
      });
    });

    group('counters', () {
      test('count increments and logs', () {
        log.runZoned(() {
          Log.count('test-counter');
          Log.count('test-counter');
          Log.count('test-counter');
        });

        final counts = output.records.where((r) => r.message.contains('test-counter:')).map((r) => r.message).toList();
        expect(counts, ['test-counter: 1', 'test-counter: 2', 'test-counter: 3']);
      });

      test('countReset resets to zero', () {
        log.runZoned(() {
          Log.count('resettable');
          Log.count('resettable');
          Log.countReset('resettable');
          Log.count('resettable');
        });

        final lastCount = output.records.last.message;
        expect(lastCount, 'resettable: 1');
      });

      test('counter level is debug', () {
        log.runZoned(() => Log.count('level-test'));
        expect(output.lastLevel, LogLevel.debug);
      });
    });

    group('assert_', () {
      test('logs warning when condition false', () {
        log.runZoned(() => Log.assert_(false, 'should fail'));

        expect(output.lastLevel, LogLevel.warn);
        expect(output.lastMessage, contains('Assertion failed: should fail'));
      });

      test('does not log when condition true', () {
        log.runZoned(() => Log.assert_(true, 'should pass'));
        expect(output.records, isEmpty);
      });
    });

    group('scoped', () {
      test('scoped logger has scope prefix', () {
        log.runZoned(() {
          Log.scoped('MyComponent').logInfo('test message');
        });

        expect(output.last.scope, 'MyComponent');
      });

      test('scoped logger shares state with parent', () {
        log.runZoned(() {
          Log.group('parent group');
          Log.scoped('Child').logInfo('in group');
        });

        final inGroup = output.records.firstWhere((r) => r.message == 'in group');
        expect(inGroup.depth, 1);
      });

      test('scoped returns NullOutput logger when no zone logger', () {
        Log.scoped('Orphan').logInfo('should not crash');
        // No exception means success
      });
    });

    group('zone propagation', () {
      test('logger available in nested async calls', () async {
        await log.runZoned(() async {
          await Future<void>.delayed(Duration.zero);
          Log.info('async message');
        });

        expect(output.records.any((r) => r.message == 'async message'), isTrue);
      });

      test('logger available in spawned futures', () async {
        log.runZoned(() {
          unawaited(Future<void>.microtask(() => Log.info('microtask message')));
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(output.records.any((r) => r.message == 'microtask message'), isTrue);
      });
    });

    group('instance methods', () {
      test('instance log methods work', () {
        log.runZoned(() {
          Log.scoped('Test')
            ..logFatal('fatal')
            ..logError('error')
            ..logWarn('warn')
            ..logInfo('info')
            ..logDebug('debug')
            ..logTrace('trace');
        });

        expect(output.records.length, 6);
        expect(output.records.map((r) => r.level).toList(), [
          LogLevel.fatal,
          LogLevel.error,
          LogLevel.warn,
          LogLevel.info,
          LogLevel.debug,
          LogLevel.trace,
        ]);
      });

      test('instance lazy methods work', () {
        log.runZoned(() {
          Log.scoped('Test')
            ..logFatalLazy(() => 'lazy fatal')
            ..logErrorLazy(() => 'lazy error')
            ..logWarnLazy(() => 'lazy warn')
            ..logInfoLazy(() => 'lazy info')
            ..logDebugLazy(() => 'lazy debug')
            ..logTraceLazy(() => 'lazy trace');
        });

        expect(output.records.length, 6);
      });
    });
  });

  group('FileOutput', () {
    late Directory tempDir;
    late String logPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('kiko_log_test_');
      logPath = '${tempDir.path}/test.log';
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('writes to file', () async {
      final output = FileOutput(logPath)
        ..write(
          LogRecord(
            timestamp: DateTime(2025, 1, 15, 10, 30, 45),
            level: LogLevel.info,
            message: 'test message',
          ),
        );
      await output.close();

      final content = await File(logPath).readAsString();
      expect(content, contains('test message'));
    });

    test('appends to existing file', () async {
      await File(logPath).writeAsString('existing content\n');

      final output = FileOutput(logPath)
        ..write(
          LogRecord(
            timestamp: DateTime(2025, 1, 15, 10, 30, 45),
            level: LogLevel.info,
            message: 'appended',
          ),
        );
      await output.close();

      final content = await File(logPath).readAsString();
      expect(content, contains('existing content'));
      expect(content, contains('appended'));
    });

    test('uses custom formatter', () async {
      final customFormatter = LogFormatter((r) => 'CUSTOM: ${r.message}');
      final output = FileOutput(logPath, formatter: customFormatter)
        ..write(
          LogRecord(
            timestamp: DateTime.now(),
            level: LogLevel.info,
            message: 'formatted',
          ),
        );
      await output.close();

      final content = await File(logPath).readAsString();
      expect(content, contains('CUSTOM: formatted'));
    });
  });
}
