/// Test doubles for driving Kiko without a terminal.
///
/// Import this from a test to run the render loop and the MVU loop under
/// `dart test`. `TestBackend` renders to memory and emits terminal events;
/// `FrameScript` feeds a running application scripted events, one per
/// committed frame.
///
/// ```dart
/// import 'package:kiko/testing.dart';
///
/// final backend = TestBackend(size: const TermSize(20, 5));
/// final terminal = await Terminal.create(backend: backend);
/// await terminal.draw((frame) => frame.render(Line('hello')));
/// expect(backend.screen[(x: 0, y: 0)].symbol, 'h');
/// ```
///
/// This is scaffolding, not production API, which is why it lives outside
/// `package:kiko/kiko.dart`.
library;

export 'src/backend/test_backend.dart';
export 'src/testing/frame_script.dart';
