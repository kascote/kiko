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
/// step's effect. A step has landed when every event emitted through
/// [backend] so far has reached `update` as its own message, and at least
/// one went out since the step was sent. So a click lands with its release,
/// not its press, and a step that emits from a timer lands when the timer's
/// events do. A report, a tick, a message the app emits itself, or the leave
/// or cancel the router delivers ahead of a pointer event never releases the
/// next step.
///
/// Every event a step emits must reach `update`. Two moves waiting in the
/// queue together coalesce into one message, and an event the runtime drops
/// becomes none; a step whose events do not all land holds the run idle until
/// the test times out. Emit one move or drag per step.
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
  int _sentAt = 0; // backend.emitCount when the pending step went out
  int _landed = 0; // events that reached update as their own message
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
      _sentAt = backend.emitCount;
      queue[_sent++](backend);
      return;
    }
    if (!_quitSent) {
      _quitSent = true;
      backend.emitKey(quitKey);
    }
  }

  /// Returns an update that answers [quitKey] with [Quit], counts a landed
  /// event, and hands every other message to [update].
  Update<M> wrap<M>(Update<M> update) => (model, msg, ctx) {
    if (msg case KeyMsg(:final key) when key == quitKey) return (model, const Quit());
    if (_isEvent(msg)) {
      _landed++;
      // The step is out until its last event lands: after a click's press,
      // the release is still in the queue.
      if (backend.emitCount > _sentAt && _landed >= backend.emitCount) _pending = false;
    }
    return update(model, msg, ctx);
  };

  /// Whether [msg] is the message the runtime made from one terminal event.
  ///
  /// The leave or cancel the router delivers ahead of a pointer event is not
  /// one: it is a side effect of the event, not the event itself.
  static bool _isEvent(Msg msg) => switch (msg) {
    KeyMsg() ||
    KeyReleaseMsg() ||
    ModifierKeyMsg() ||
    PointerMsg() ||
    FocusMsg() ||
    PasteMsg() ||
    ResizeMsg() ||
    UnknownMsg() => true,
    _ => false,
  };
}
