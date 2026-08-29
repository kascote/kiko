import '../backend/test_backend.dart';
import '../mvu/cmd.dart';
import '../mvu/msg.dart';
import '../mvu/pointer_msg.dart';
import '../terminal/application.dart';
import '../widgets/frame.dart';
import '../widgets/hit_map.dart';

/// One scripted terminal action: emits an event through [backend].
typedef ScriptStep = void Function(TestBackend backend);

/// A list of terminal events fed to a running application one per committed
/// frame, then a quit key.
///
/// Wire [onFrame] into `Application.onFrame` and wrap the app's update with
/// [wrap]:
///
/// ```dart
/// final script = FrameScript(
///   backend,
///   readyId: 'name',
///   steps: (hits) {
///     final field = hits.rectOf('name')!;
///     return [(b) => b.emitClick(field.x + 1, field.y), (b) => b.emitKey('x')];
///   },
/// );
/// await Application(backend: backend, onFrame: script.onFrame).run<M>(
///   init: model,
///   update: script.wrap(update),
///   view: view,
/// );
/// expect(script.completed, isTrue);
/// ```
///
/// A step goes out from the first frame committed after the previous step
/// landed, so the hit map in force when a step goes out shows the previous
/// step's effect. A step has landed when the message its event became
/// reaches `update`; a report, a tick, or a message the app emits itself
/// never releases the next step.
class FrameScript {
  /// Creates a script over [backend]; see [steps], [readyId] and [quitKey].
  FrameScript(this.backend, {required this.steps, this.readyId, this.quitKey = 'ctrl+q'});

  /// The backend the steps emit through.
  final TestBackend backend;

  /// Builds the step list from the hit map of the frame the script starts on:
  /// the first frame in which [readyId] is live, or the first frame at all
  /// when [readyId] is null. Called once.
  final List<ScriptStep> Function(HitMap hits) steps;

  /// The hit path — a leaf or a scope — that must be live before [steps] is
  /// built, or null to start on the first frame.
  ///
  /// A path that never paints holds the run idle until the test times out.
  final String? readyId;

  /// The key emitted after the last step's frame. [wrap] answers it with
  /// [Quit] before the app's update sees it.
  final String quitKey;

  List<ScriptStep>? _queue;
  int _sent = 0;
  bool _pending = false;
  bool _quitSent = false;
  CompletedFrame? _lastFrame;

  /// The frame committed last, or null before the first one.
  ///
  /// Once [completed], this is the frame that shows the last step's effect.
  CompletedFrame? get lastFrame => _lastFrame;

  /// Whether every step went out and the quit key followed.
  bool get completed => _quitSent;

  /// Records [frame], then sends the next step — or the quit key once every
  /// step went out.
  ///
  /// Pass it as `Application.onFrame`, or call it from a callback that also
  /// captures something of its own.
  void onFrame(CompletedFrame frame) {
    _lastFrame = frame;
    if (_pending) return;
    if (_queue == null) {
      if (readyId case final id? when !frame.hits.isLive(id)) return;
      _queue = steps(frame.hits);
    }
    final queue = _queue!;
    if (_sent < queue.length) {
      _pending = true;
      queue[_sent++](backend);
      return;
    }
    if (!_quitSent) {
      _quitSent = true;
      backend.emitKey(quitKey);
    }
  }

  /// Returns an update that answers [quitKey] with [Quit], notes a landed
  /// step, and hands every other message to [update].
  Update<M> wrap<M>(Update<M> update) => (model, msg, ctx) {
    if (msg case KeyMsg(:final key) when key == quitKey) return (model, const Quit());
    if (_fromTerminal(msg)) _pending = false;
    return update(model, msg, ctx);
  };

  /// Whether the runtime made [msg] from a terminal event — the only messages
  /// a step lands as.
  static bool _fromTerminal(Msg msg) => switch (msg) {
    KeyMsg() ||
    KeyReleaseMsg() ||
    ModifierKeyMsg() ||
    Routed() ||
    FocusMsg() ||
    PasteMsg() ||
    ResizeMsg() ||
    UnknownMsg() => true,
    _ => false,
  };
}
