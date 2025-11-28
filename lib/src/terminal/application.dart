import 'dart:async';
import 'dart:io';

import 'package:termparser/termparser_events.dart';

import 'terminal.dart';

/// Application class handles the terminal initialization and cleanup.
class Application {
  /// The terminal instance to use
  late final Terminal terminal;

  /// The viewport instance to use
  late final ViewPort viewport;

  Application._();

  /// Creates a new Application instance.
  ///
  /// If [terminal] is not provided, a new terminal instance will be created.
  /// The [terminal] parameters is useful for testing purposes.
  static Future<Application> create({
    Terminal? terminal,
    ViewPort? viewport,
  }) async {
    final app = Application._()
      ..terminal = terminal ?? await Terminal.create()
      ..viewport = viewport ?? const ViewPortFullScreen();
    return app;
  }

  /// Runs the application main loop. The value that return, will be the exit
  /// code to use to end the application.
  Future<int> run(WidgetRenderCallback builder) async {
    final exitValue = await runZonedGuarded(
      () async {
        _initTerminal();
        final rc = await _runLoop(builder);
        await _deinitTerminal();
        return rc;
      },
      (error, stackTrace) async {
        await _deinitTerminal();
        stderr
          ..writeln('Error: $error')
          ..writeln('Stack: $stackTrace');
      },
    );

    // TODO(nelson): handle exit value properly
    return exitValue ?? 128;
  }

  /// Runs the application main loop. The value that return, will be the exit
  /// code to use to end the application.
  Future<int> _runLoop(WidgetRenderCallback builder) async {
    while (true) {
      terminal.draw(builder);
      final key = await terminal.readEvent<KeyEvent>(timeout: 1 ~/ 60);
      if (key is KeyEvent) {
        if (key.code.char == 'q') break;
      }
    }
    return 0;
  }

  void _initTerminal() {
    if (viewport is ViewPortFullScreen) {
      terminal
        ..enableAlternateScreen()
        ..hideCursor()
        ..enableRawMode();
    }
  }

  Future<void> _deinitTerminal() async {
    if (viewport is ViewPortFullScreen) {
      terminal
        ..disableRawMode()
        ..disableAlternateScreen()
        ..showCursor();
    }
  }
}
