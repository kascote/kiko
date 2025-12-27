# kiko_log

Zone-based structured logging for TUI apps. Designed for alternate screen mode where stdout isn't available.

## Features

- Simple API with readable level names (fatal/error/warn/info/debug/trace)
- Zone-based storage (no globals, auto-propagates through async)
- File output with configurable flush behavior
- Chrome DevTools-style timers, groups, and counters
- Lazy evaluation to avoid string building when level disabled
- Scoped loggers for component prefixes

## Usage

### Basic

```dart
import 'package:kiko_log/kiko_log.dart';

void main() {
  final log = Log(
    output: FileOutput('app.log'),
    level: LogLevel.debug,
  );

  log.runZoned(() {
    Log.info('Application started');
    Log.debug('Processing items');
    Log.error('Something failed', exception, stackTrace);
  });
}
```

### With Application

```dart
await Application(
  logPath: 'myapp.log',
  logLevel: LogLevel.debug,
).run(...);

// Anywhere in app
Log.info('user logged in');
Log.debug('processing ${items.length} items');
```

### Scoped Loggers

```dart
class MyComponent {
  final log = Log.scoped('MyComponent');

  void process() {
    log.logDebug('processing');  // → [DEBUG] MyComponent: processing
  }
}
```

### Timers

```dart
Log.time('render');
doExpensiveWork();
Log.timeEnd('render');  // → [DEBUG] render: 12.34ms
```

### Groups

```dart
Log.group('Request');
  Log.info('parsing body');
  Log.debug('body size: 1024');
Log.groupEnd('Request');
```

Output:

```
[INFO]  ▶ Request
[INFO]    parsing body
[DEBUG]   body size: 1024
[INFO]  ◀ Request
```

### Lazy Evaluation

```dart
// Callback only invoked if debug level enabled
Log.debugLazy(() => 'expensive: ${computeDebugInfo()}');
```

### Counters

```dart
Log.count('frame-drop');  // → [DEBUG] frame-drop: 1
Log.count('frame-drop');  // → [DEBUG] frame-drop: 2
Log.countReset('frame-drop');
```

### Assert

```dart
Log.assert_(items.isNotEmpty, 'items should not be empty');
// Logs warning only if condition is false
```

## Log Levels

| Level | Use                  |
| ----- | -------------------- |
| fatal | App cannot continue  |
| error | Failures, exceptions |
| warn  | Potential issues     |
| info  | Significant events   |
| debug | Detailed flow        |
| trace | Everything           |

## Formatters

**Standard** (default):

```
[2025-01-15 10:30:45.123] [INFO ] message
```

**Compact**:

```
10:30:45.123 INFO  message
```

Custom:

```dart
final custom = LogFormatter((r) => '${r.level}: ${r.message}');
FileOutput('app.log', formatter: custom);
```
