// This example runs every id-addressing rule the framework has, one case at
// a time: a flat spinner, one reachable only through `extras`, a panel
// around one part, a panel inside a panel, twin panels that share a part id,
// a panel and its own part sharing one id, a panel with two parts started by
// a single batch, a restart with a bumped generation, and a panel that asks
// the app to load something and stops itself once the answer lands.
//
// Each case gets its own box on screen, its own look, and its own line in
// the source below. Tab cycles focus through the cases; the status line
// shows what the focused case proves. Press a case's key to start or stop
// it, and watch the caption for what to look for.

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════

/// Emitted when an animated part's running state toggles — by Enter or by a
/// click alike. Addresses the part by [id].
class SpinnerToggleEvent extends WidgetEvent {
  /// Creates the event carrying the part's [id] and its [running] state
  /// right after the toggle.
  const SpinnerToggleEvent(this.id, {required this.running});

  /// The id of the part that toggled.
  @override
  final String id;

  /// Whether the part is running after the toggle.
  final bool running;
}

/// Emitted when a panel's part toggles, in place of the part's own event.
///
/// A [PanelModel] never lets a part's event through unchanged: it reads the
/// part's own toggle and re-addresses it as one of these, naming itself as
/// [id] and the part as [part]. A panel nested inside another panel is
/// re-addressed again the same way, so the app only ever sees ids it
/// registered with its `FocusRouter`.
class PanelToggleEvent extends WidgetEvent {
  /// Creates the event: the panel's own [id], the [part] that toggled, and
  /// its [running] state right after the toggle.
  const PanelToggleEvent(this.id, {required this.part, required this.running});

  /// The id of the panel that produced this event.
  @override
  final String id;

  /// The bare id of the part that toggled — a leaf part's own id, or a
  /// nested panel's own id.
  final String part;

  /// Whether the part is running after the toggle.
  final bool running;
}

// ═══════════════════════════════════════════════════════════
// MESSAGES
// ═══════════════════════════════════════════════════════════

/// Riding alongside the ticks a [PanelModel.startAll] batch scopes, so the
/// batch always carries one command [ScopeTicks] never touches.
///
/// The app records [id] in its fall-through and otherwise ignores this; every
/// model declines it, since none of them ever starts a panel.
class PanelStartedMsg extends Msg {
  /// Creates the message for the panel started at [id].
  const PanelStartedMsg(this.id);

  /// The id of the panel that started.
  final String id;
}

// ═══════════════════════════════════════════════════════════
// ANIMATED PART
// ═══════════════════════════════════════════════════════════

/// The control surface every animated part exposes, on top of [Component]:
/// arm, disarm, and report whether an animation is currently live.
///
/// A [PanelModel] holds its parts as [Animated] rather than bare
/// [Component]s, so it can start, stop, and restart them — and read whether
/// they are running — without a type switch: a leaf look and a nested panel
/// answer the same way. [AnimatedModel] and [PanelModel] are its only two
/// implementers, both in this file.
sealed class Animated implements Component {
  /// Whether this part's tick chain is armed — or, for a panel, whether any
  /// part's chain, or its own blink, is.
  bool get running;

  /// The hit path of every tick chain currently live under this part.
  List<String> get liveChains;

  /// Arms the part, or does nothing if it is already running.
  Cmd? start();

  /// Stops the part. A tick already in flight lands and is not re-armed.
  Cmd? stop();

  /// Stops any current chain and arms a fresh one, running or not.
  Cmd? restart();
}

/// The shared shape of every leaf animated look: a running flag, a frame
/// counter, and a generation that guards its own tick chain.
///
/// A subclass overrides [advance] to move its own state forward one frame,
/// and [text] to render it as one line. [start], [stop] and [restart] are
/// the control surface a panel or the app drives directly. Enter while
/// focused, and a pointer press on the part's own cells, both go through
/// [update] instead and toggle it the same way, emitting [SpinnerToggleEvent].
/// A part always arms its tick with its own bare [id] — never the path it
/// may have arrived under — because a part has no way to know what, if
/// anything, wraps it.
abstract class AnimatedModel implements Animated {
  /// Creates a part with its own [id] and tick [interval].
  AnimatedModel({required this.id, this.interval = const Duration(milliseconds: 80)});

  @override
  final String id;

  /// How long the part waits between frames.
  final Duration interval;

  /// A subclass-owned counter: a frame index, a position, a fill amount —
  /// whatever [advance] needs to move this look forward by one step.
  int frameIndex = 0;

  @override
  bool running = false;

  /// The running tick chain's generation. [start] and [restart] bump it, so a
  /// tick armed before either lands stale and is not re-armed.
  int generation = 0;

  bool _focused = false;

  /// Whether this part owns keyboard input.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  /// Moves this look's state forward by one frame. Called only while
  /// [running]; a subclass mutates whatever field its look needs.
  void advance();

  /// The one line of text this look paints for its current state.
  String get text;

  @override
  Cmd? start() {
    if (running) return null;
    running = true;
    generation++;
    return Tick(interval, id: id, key: generation);
  }

  @override
  Cmd? stop() {
    running = false;
    return null;
  }

  @override
  Cmd? restart() {
    running = true;
    generation++;
    return Tick(interval, id: id, key: generation);
  }

  @override
  List<String> get liveChains => running ? [id] : const [];

  /// Handles a message, reporting whether it was consumed and what it
  /// produced.
  ///
  /// A pointer press on this part's own cells toggles it above the focus
  /// gate; every other pointer message on them is consumed with no effect,
  /// since a part tracks no hover or capture state. A pointer whose path
  /// does not end in this part's id is declined. A [TickMsg] whose leaf
  /// names this part calls [advance] and re-arms when [running] and the key
  /// matches [generation]; a stale or stopped tick is consumed but not
  /// re-armed. Enter toggles the part while focused. Everything else is
  /// declined.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      if (pointer.isWheel) return const Declined();
      // A pointer is this part's only when its path ends in this id.
      if (pointer.targetId case final target? when HitTag.leafOf(target) == id) {
        return pointer.isDown ? _toggle() : const Handled();
      }
      return const Declined();
    }
    if (msg is PointerLeaveMsg || msg is PointerCancelMsg) return const Declined();

    if (msg case TickMsg(id: final path, :final key) when HitTag.leafOf(path) == id) {
      if (!running || key != generation) return const Handled();
      advance();
      return Handled(
        cmd: Tick(interval, id: id, key: generation),
      );
    }

    if (!focused) return const Declined();
    if (msg case KeyMsg(key: 'enter')) return _toggle();
    return const Declined();
  }

  UpdateResult _toggle() {
    final cmd = running ? stop() : start();
    return Handled(
      events: [SpinnerToggleEvent(id, running: running)],
      cmd: cmd,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LOOKS
// ═══════════════════════════════════════════════════════════

const List<String> _brailleFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

/// A braille spinner: cycles [frames], idle at `·`.
///
/// The braille look for the member, panel and echo cases.
class SpinnerModel extends AnimatedModel {
  /// Creates a spinner with its own [id] and tick [interval]. [frames] is
  /// the glyph cycle it paints; it defaults to a braille spinner.
  SpinnerModel({required super.id, super.interval, List<String>? frames}) : frames = frames ?? _brailleFrames;

  /// The glyphs this spinner cycles through while running.
  final List<String> frames;

  @override
  void advance() => frameIndex = (frameIndex + 1) % frames.length;

  @override
  String get text => running ? frames[frameIndex % frames.length] : '·';
}

/// A dot bouncing back and forth inside a fixed-width track.
///
/// The bouncer look for the extra case and both duo parts.
class BouncerModel extends AnimatedModel {
  /// Creates a bouncer with its own [id] and tick [interval]. [width] is the
  /// track's inner width, in cells.
  BouncerModel({required super.id, super.interval, this.width = 7});

  /// The track's inner width, in cells.
  final int width;

  int get _cycle => 2 * (width - 1);

  @override
  void advance() => frameIndex = (frameIndex + 1) % _cycle;

  int get _position {
    final phase = frameIndex % _cycle;
    return phase < width - 1 ? phase : _cycle - phase;
  }

  @override
  String get text {
    if (!running) return '│${' ' * width}│';
    final track = List.filled(width, ' ');
    track[_position] = '●';
    return '│${track.join()}│';
  }
}

/// A row of equalizer bars, each cycling through a height ramp out of phase
/// with its neighbors.
///
/// The bars look for both twin panels, each at its own speed.
class BarsModel extends AnimatedModel {
  /// Creates a bars display with its own [id] and tick [interval]. [barCount]
  /// is how many bars it paints.
  BarsModel({required super.id, super.interval, this.barCount = 5});

  /// How many bars this look paints side by side.
  final int barCount;

  static const _levels = '▁▂▃▄▅▆▇█';

  @override
  void advance() => frameIndex = (frameIndex + 1) % _levels.length;

  @override
  String get text {
    if (!running) return _levels[0] * barCount;
    return [for (var i = 0; i < barCount; i++) _levels[(frameIndex + i * 2) % _levels.length]].join();
  }
}

/// Scrolling text inside a fixed-width window.
///
/// The marquee look for the part nested two panels deep.
class MarqueeModel extends AnimatedModel {
  /// Creates a marquee with its own [id] and tick [interval]. [message] is
  /// the text that scrolls; [width] is the visible window, in cells.
  MarqueeModel({required super.id, super.interval, this.message = 'kiko rules the terminal   ', this.width = 14});

  /// The text that scrolls through the window.
  final String message;

  /// The visible window's width, in cells.
  final int width;

  @override
  void advance() => frameIndex = (frameIndex + 1) % message.length;

  @override
  String get text {
    if (!running) return ' ' * width;
    final doubled = message + message;
    return doubled.substring(frameIndex, frameIndex + width);
  }
}

/// A fill bar that advances while running, then reads `loaded` once stopped
/// with progress already made, and resets on the next start.
///
/// The progress look for the loader case's part.
class ProgressModel extends AnimatedModel {
  /// Creates a progress bar with its own [id] and tick [interval]. [barWidth]
  /// is the bar's width in cells; [steps] is how many ticks a full fill
  /// takes.
  ProgressModel({required super.id, super.interval, this.barWidth = 10, this.steps = 16});

  /// The bar's width, in cells.
  final int barWidth;

  /// How many ticks a full fill takes.
  final int steps;

  @override
  Cmd? start() {
    if (!running) frameIndex = 0;
    return super.start();
  }

  @override
  void advance() => frameIndex = (frameIndex + 1).clamp(0, steps);

  @override
  String get text {
    if (!running && frameIndex == 0) return '[${' ' * barWidth}] 0%';
    if (!running) return '[${'█' * barWidth}] loaded';
    final filled = (frameIndex * barWidth / steps).round().clamp(0, barWidth);
    final percent = (frameIndex * 100 / steps).round().clamp(0, 100);
    return '[${'█' * filled}${'░' * (barWidth - filled)}] $percent%';
  }
}

// ═══════════════════════════════════════════════════════════
// ANIMATED VIEW
// ═══════════════════════════════════════════════════════════

/// The render half of any [AnimatedModel]: one line of [AnimatedModel.text],
/// self-tagged with the model's id.
final class AnimatedView implements View {
  /// Creates a view over [model], styled by [theme].
  const AnimatedView({required this.model, required this.theme});

  /// The model whose text and running state this view paints.
  final AnimatedModel model;

  /// The theme that resolves the part's ink.
  final Theme theme;

  @override
  Node build() {
    final resolver = StyleResolver(theme);
    final t = resolver.tones;
    final style = model.running ? resolver.ink(t.accent) : resolver.ink(t.muted);
    return Line(model.text, style: style).build()..tag = IdTag(model.id);
  }
}

// ═══════════════════════════════════════════════════════════
// PANEL MODEL
// ═══════════════════════════════════════════════════════════

/// A composite that embeds a fixed list of [Animated] parts — a leaf look or
/// a nested [PanelModel] — and forwards to the one a delivered path names.
///
/// [startAll], [stopAll] and [restartAll] drive every part at once through
/// one command, scoped once so a part's `Tick` reaches it again after one
/// more hop outward. Interactive traffic — Enter, or a click on a part —
/// reaches [update] instead: a part's own [SpinnerToggleEvent] or
/// [PanelToggleEvent] is always re-addressed as a [PanelToggleEvent] naming
/// this panel, never let through unchanged. A panel with [blinkInterval] set
/// also owns one tick chain of its own — its border's blink — armed with its
/// own bare [id]. A panel with [loads] set asks the app for data when it
/// starts, through a [LoadRequest], and stops every part once the matching
/// [LoadResult] lands.
class PanelModel implements Animated {
  /// Creates a panel over [parts], keyed by their own bare id. [blinkInterval]
  /// gives the panel's own border a blink; leave it null for a panel with no
  /// blink of its own. [loads] makes [startAll] also ask the app to load
  /// something, addressed by this panel's own [id].
  PanelModel({required this.id, required this.parts, this.blinkInterval, this.loads = false});

  @override
  final String id;

  /// This panel's parts, in the order [update] tries them for a keystroke.
  final List<Animated> parts;

  /// How often this panel's own border blinks, or null for no blink.
  final Duration? blinkInterval;

  /// Whether starting this panel also asks the app to load something,
  /// addressed by this panel's own [id].
  final bool loads;

  late final Map<String, Animated> _byId = {for (final part in parts) part.id: part};

  bool _focused = false;

  /// Whether this panel owns keyboard input.
  bool get focused => _focused;

  @override
  set focused(bool value) {
    _focused = value;
    for (final part in parts) {
      part.focused = value;
    }
  }

  /// Whether this panel's border is in its lit phase, while [blinkInterval]
  /// is set and the blink is running.
  bool blinkOn = false;

  bool _blinkRunning = false;
  int _blinkGeneration = 0;

  /// Whether a load this panel asked for is in flight.
  bool loading = false;

  int _loadGeneration = 0;

  /// How many ticks this panel has handled as its own — its blink — never a
  /// part's. Stays at zero for a panel with no [blinkInterval], and for a
  /// panel whose part shares its own id: forwarding to the part always runs
  /// first.
  int ownTicks = 0;

  @override
  bool get running => loading || _blinkRunning || parts.any((part) => part.running);

  @override
  List<String> get liveChains => [
    if (_blinkRunning) id,
    for (final part in parts)
      for (final chain in part.liveChains) HitTag.join(id, chain),
  ];

  // The three methods below each scope the parts' commands exactly once,
  // then add this panel's own tick — armed with its own bare id — outside
  // that scope. Scoping the own tick too would double its prefix once this
  // panel is itself nested as a part under another one.

  @override
  Cmd? start() {
    final partsCmd = _scopeCmd(Batch(<Cmd?>[for (final part in parts) part.start()]));
    return Batch(<Cmd?>[partsCmd, _startBlink()]);
  }

  @override
  Cmd? stop() {
    final partsCmd = _scopeCmd(Batch(<Cmd?>[for (final part in parts) part.stop()]));
    _stopBlink();
    loading = false;
    return partsCmd;
  }

  @override
  Cmd? restart() {
    final partsCmd = _scopeCmd(Batch(<Cmd?>[for (final part in parts) part.restart()]));
    final interval = blinkInterval;
    Cmd? blinkCmd;
    if (interval != null) {
      _blinkRunning = true;
      _blinkGeneration++;
      blinkCmd = Tick(interval, id: id, key: _blinkGeneration);
    }
    return Batch(<Cmd?>[partsCmd, blinkCmd]);
  }

  /// Starts every part, and this panel's own blink if it has one, through one
  /// command. A panel already fully running is a safe no-op: every part call
  /// is idempotent, so re-pressing the key that starts an already-running
  /// case starts nothing twice. When [loads], also asks the app for data with
  /// a freshly bumped generation. The batch always carries one non-tick
  /// [PanelStartedMsg], so the scoping helper's pass-through stays visible
  /// next to the parts' ticks.
  UpdateResult startAll() {
    final cmd = start();
    final events = <WidgetEvent>[];
    if (loads && !loading) {
      loading = true;
      _loadGeneration++;
      events.add(LoadRequest(id, key: _loadGeneration));
    }
    return Handled(events: events, cmd: Batch([cmd, Emit(PanelStartedMsg(id))]));
  }

  /// Stops every part, and this panel's own blink, through one command.
  UpdateResult stopAll() => Handled(cmd: stop());

  /// Restarts every part with a bumped generation, and re-arms this panel's
  /// own blink the same way, whether or not either was already running.
  UpdateResult restartAll() => Handled(cmd: restart());

  /// Handles a message, reporting whether it was consumed and what it
  /// produced.
  ///
  /// A message addressed under this panel's id, or a pointer routed to a
  /// path under it, is forwarded to the part the next segment names, before
  /// any guard below — so a part sharing this panel's own id is still
  /// reached first. A [LoadResult] whose leaf is this panel's own id installs
  /// its answer. A pointer on the panel's own scope path — its border, or a
  /// gap between parts — is consumed and does nothing; its wheel is declined,
  /// for a scrollable ancestor to take. A [TickMsg] whose leaf is this
  /// panel's own id is its blink. Keyboard sits behind the focus gate: it is
  /// tried against each part in order, and the first part to handle it wins.
  /// Everything else is declined.
  @override
  UpdateResult update(Msg msg) {
    final path = _addressOf(msg);
    if (path != null) {
      final part = HitTag.partOn(path, under: id, parts: _byId.keys.toSet());
      if (part != null) return _fromPart(_byId[part]!.update(msg));
    }

    if (msg case final LoadResult<Object?> result when HitTag.leafOf(result.id) == id) {
      return _applyLoad(result);
    }

    if (msg case final PointerMsg pointer) {
      if (pointer.isWheel) return const Declined();
      // Only the panel's own scope path is its own; any other path names
      // something this panel does not hold.
      if (pointer.targetId case final target? when HitTag.leafOf(target) == id) return const Handled();
      return const Declined();
    }
    if (msg is PointerLeaveMsg || msg is PointerCancelMsg) return const Declined();

    if (msg case TickMsg(id: final path, :final key) when HitTag.leafOf(path) == id) {
      return _handleOwnTick(key);
    }

    if (!focused) return const Declined();
    if (msg case final KeyMsg key) return _forwardKey(key);

    return const Declined();
  }

  static String? _addressOf(Msg msg) => switch (msg) {
    Addressed(:final id) => id,
    Routed(:final targetId?) => targetId,
    _ => null,
  };

  UpdateResult _forwardKey(KeyMsg key) {
    for (final part in parts) {
      final result = part.update(key);
      if (result is Handled) return _fromPart(result);
    }
    return const Declined();
  }

  /// Scopes a part's `Tick`s under this panel's id, and re-addresses any
  /// toggle event it produced as this panel's own [PanelToggleEvent].
  UpdateResult _fromPart(UpdateResult result) {
    final scoped = result.scopeTicks(id);
    if (scoped is! Handled) return scoped;
    return Handled(cmd: scoped.cmd, events: [for (final event in scoped.events) _translate(event)]);
  }

  WidgetEvent _translate(WidgetEvent event) => switch (event) {
    final SpinnerToggleEvent e => PanelToggleEvent(id, part: e.id, running: e.running),
    final PanelToggleEvent e => PanelToggleEvent(id, part: e.part, running: e.running),
    final other => throw StateError('PanelModel "$id" cannot translate ${other.runtimeType}'),
  };

  UpdateResult _handleOwnTick(Object? key) {
    ownTicks++;
    if (!_blinkRunning || key != _blinkGeneration) return const Handled();
    blinkOn = !blinkOn;
    return Handled(
      cmd: Tick(blinkInterval!, id: id, key: _blinkGeneration),
    );
  }

  UpdateResult _applyLoad(LoadResult<Object?> result) {
    if (!loading || result.key != _loadGeneration) return const Handled();
    return Handled(cmd: stop());
  }

  Cmd? _startBlink() {
    final interval = blinkInterval;
    if (interval == null || _blinkRunning) return null;
    _blinkRunning = true;
    _blinkGeneration++;
    return Tick(interval, id: id, key: _blinkGeneration);
  }

  Cmd? _stopBlink() {
    _blinkRunning = false;
    return null;
  }

  /// Scopes [cmd] under this panel's id, the way [_fromPart] scopes a part's
  /// result. [ScopeTicks] works on an [UpdateResult], so the command rides
  /// in a [Handled] for the call.
  Cmd? _scopeCmd(Cmd cmd) => (Handled(cmd: cmd).scopeTicks(id) as Handled).cmd;
}

// ═══════════════════════════════════════════════════════════
// PANEL VIEW
// ═══════════════════════════════════════════════════════════

/// The render half of a [PanelModel]: a bordered box around its parts,
/// scoped under the model's id. [title] overrides the border's title —
/// nested calls leave it null and show the model's bare id instead. [caption]
/// appends one muted line below the parts, for a case's `watch` text.
final class PanelView implements View {
  /// Creates a panel view over [model], styled by [theme].
  const PanelView({required this.model, required this.theme, this.title, this.caption});

  /// The model whose parts and blink state this view paints.
  final PanelModel model;

  /// The theme that resolves the panel's chrome.
  final Theme theme;

  /// The border's title, or null to show the model's bare id.
  final String? title;

  /// A muted caption line below the parts, or null for none.
  final String? caption;

  @override
  Node build() {
    final resolver = StyleResolver(theme);
    final t = resolver.tones;
    var borderStyle = resolver.border({if (model.focused) WidgetState.focused});
    if (model.blinkInterval != null && model.blinkOn) {
      borderStyle = borderStyle.patch(resolver.ink(t.error));
    }
    return Tagged.scope(
      model.id,
      Container(
        border: BorderType.plain,
        borderStyle: borderStyle,
        topTitles: [Line(' ${title ?? model.id} ', style: resolver.ink(t.muted))],
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Column(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            for (final part in model.parts) _partView(part, theme),
            if (caption case final caption?) Line(caption, style: resolver.ink(t.muted)),
          ],
        ),
      ),
    ).build();
  }
}

/// Renders one part inside a [PanelView]. The one place in this example
/// allowed to switch on a part's type: everywhere else, [Animated] is
/// enough.
View _partView(Animated part, Theme theme) => switch (part) {
  final PanelModel p => PanelView(model: p, theme: theme),
  final AnimatedModel a => AnimatedView(model: a, theme: theme),
};

// ═══════════════════════════════════════════════════════════
// CASE
// ═══════════════════════════════════════════════════════════

/// One addressing case: the key that drives it, the models it holds, and the
/// prose that explains what it stresses and what to watch for.
///
/// [members] joins the app's focus group; [extras] joins its router's extras
/// — reachable by address but never focused. Most cases contribute exactly
/// one of the two; the twins case contributes two members at once. The clock
/// is not a [Case]: it has no component, and the app's own fall-through
/// ticks it directly.
class Case {
  /// Creates a case bound to [key], with its explanatory text, its models,
  /// and the operations [key] and the global start/stop keys drive.
  Case({
    required this.key,
    required this.title,
    required this.ids,
    required this.proves,
    required this.watch,
    required this.toggle,
    required this.start,
    required this.stop,
    required this.liveChains,
    required this.box,
    this.members = const [],
    this.extras = const [],
  });

  /// The single-letter key that drives this case.
  final String key;

  /// The box title: `key · ids`.
  final String title;

  /// Every hit path this case's parts arm a `Tick` under.
  final List<String> ids;

  /// The rule this case stresses, shown on the status line while focused.
  final String proves;

  /// What to look for on screen, shown as the box's caption.
  final String watch;

  /// Starts this case if idle, stops it if running.
  final UpdateResult Function() toggle;

  /// Starts this case unconditionally — a safe no-op if already running.
  final UpdateResult Function() start;

  /// Stops this case unconditionally.
  final UpdateResult Function() stop;

  /// The hit path of every tick chain this case currently has live.
  final List<String> Function() liveChains;

  /// Renders this case's box.
  final View Function(Theme theme, StyleResolver resolver) box;

  /// The focus members this case contributes, if any.
  final List<Component> members;

  /// The router extras this case contributes, if any.
  final List<Component> extras;
}

/// Combines several parts' outcomes into one, so a combined action — start
/// every part of a multi-member case at once — still resolves through a
/// single `Batch` and one events list.
UpdateResult _combine(List<UpdateResult> results) {
  final events = <WidgetEvent>[];
  final cmds = <Cmd?>[];
  for (final result in results) {
    if (result is! Handled) continue;
    events.addAll(result.events);
    cmds.add(result.cmd);
  }
  return Handled(events: events, cmd: Batch(cmds));
}

/// Builds a bordered box for a case with exactly one flat, non-panel part —
/// the shape the member and extra cases share.
View _flatBox(String title, String watch, AnimatedModel model, Theme theme, StyleResolver resolver) {
  final t = resolver.tones;
  return Container(
    border: BorderType.plain,
    borderStyle: resolver.border({if (model.focused) WidgetState.focused}),
    topTitles: [Line(' $title ', style: resolver.ink(t.muted))],
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        AnimatedView(model: model, theme: theme),
        Line(watch, style: resolver.ink(t.muted)),
      ],
    ),
  );
}

/// Builds a box for a case with exactly one panel — the shape the panel,
/// nested, echo, duo and loader cases share. [PanelView] already draws its
/// own border and caption; this only fixes the title it shows.
View _panelBox(String title, String watch, PanelModel model, Theme theme) =>
    PanelView(model: model, theme: theme, title: title, caption: watch);

// ═══════════════════════════════════════════════════════════
// CASE: MEMBER (m)
// ═══════════════════════════════════════════════════════════

// A flat spinner joins the focus group directly, with no panel around it.
// It proves the baseline: a part with no composite wrapping it still arms
// its tick with its own bare id, and Tab reaches it like any other member.

Case _memberCase(Duration step) {
  final model = SpinnerModel(id: 'member', interval: step);
  const title = 'm · member';
  const watch = 'enter toggles while focused';
  return Case(
    key: 'm',
    title: title,
    ids: const ['member'],
    proves: 'A flat focus member arms its own bare id; no panel wraps it.',
    watch: watch,
    members: [model],
    toggle: () => Handled(cmd: model.running ? model.stop() : model.start()),
    start: () => Handled(cmd: model.start()),
    stop: () => Handled(cmd: model.stop()),
    liveChains: () => model.liveChains,
    box: (theme, resolver) => _flatBox(title, watch, model, theme, resolver),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: EXTRA (x)
// ═══════════════════════════════════════════════════════════

// A bouncer reachable only through the router's extras: never a focus-group
// member, so Tab never lands on it, but an addressed message — its own
// tick — still resolves to it directly, by id, with no traversal involved.

Case _extraCase(Duration step) {
  final model = BouncerModel(id: 'extra', interval: step);
  const title = 'x · extra';
  const watch = 'unfocusable, ticks by id';
  return Case(
    key: 'x',
    title: title,
    ids: const ['extra'],
    proves: 'A router extra is reachable by address but never joins Tab.',
    watch: watch,
    extras: [model],
    toggle: () => Handled(cmd: model.running ? model.stop() : model.start()),
    start: () => Handled(cmd: model.start()),
    stop: () => Handled(cmd: model.stop()),
    liveChains: () => model.liveChains,
    box: (theme, resolver) => _flatBox(title, watch, model, theme, resolver),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: PANEL (p, r)
// ═══════════════════════════════════════════════════════════

// A panel around one spinner: the composite shape every other panel case
// builds on. `p` toggles it; `r` restarts it with a bumped generation, so a
// tick armed before the restart lands stale and is not re-armed.

Case _panelCase(Duration step) {
  final model = PanelModel(
    id: 'panel',
    parts: [SpinnerModel(id: 'spinner', interval: step)],
  );
  const title = 'p/r · panel/spinner';
  const watch = 'r restarts, new generation';
  return Case(
    key: 'p',
    title: title,
    ids: const ['panel/spinner'],
    proves:
        'A composite forwards to the part its path names, before its own guard, '
        "and scopes the part's ticks on the way out.",
    watch: watch,
    members: [model],
    toggle: () => model.running ? model.stopAll() : model.startAll(),
    start: model.startAll,
    stop: model.stopAll,
    liveChains: () => model.liveChains,
    box: (theme, resolver) => _panelBox(title, watch, model, theme),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: NESTED (n)
// ═══════════════════════════════════════════════════════════

// A panel inside a panel: forwarding recurses two hops deep to reach the
// marquee. The inner panel's own blink tick sits beside the tick it
// forwards for its part, so the HUD's tick set shows both `outer/inner`
// (the blink) and `outer/inner/marquee` (the part) at once.

Case _nestedCase(Duration step) {
  final marquee = MarqueeModel(id: 'marquee', interval: step);
  final inner = PanelModel(id: 'inner', parts: [marquee], blinkInterval: step * 10);
  final outer = PanelModel(id: 'outer', parts: [inner]);
  const title = 'n · outer/inner/marquee';
  const watch = 'inner border blinks, own clock';
  return Case(
    key: 'n',
    title: title,
    ids: const ['outer/inner', 'outer/inner/marquee'],
    proves:
        'Forwarding recurses: outer finds inner, inner finds the marquee. '
        "A nested panel's own blink tick is never rewritten; its part's tick is.",
    watch: watch,
    members: [outer],
    toggle: () => outer.running ? outer.stopAll() : outer.startAll(),
    start: outer.startAll,
    stop: outer.stopAll,
    liveChains: () => outer.liveChains,
    box: (theme, resolver) => _panelBox(title, watch, outer, theme),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: TWINS (t)
// ═══════════════════════════════════════════════════════════

// Two separate panels share one part id: `a/bars` and `b/bars` never
// collide, because each resolves through its own panel's scope. One key
// drives both at once; each still runs, and stops, on its own.

Case _twinsCase(Duration step) {
  final a = PanelModel(
    id: 'a',
    parts: [BarsModel(id: 'bars', interval: step)],
  );
  final b = PanelModel(
    id: 'b',
    parts: [BarsModel(id: 'bars', interval: step * 2)],
  );
  const title = 't · a/bars, b/bars';
  const watch = 'a faster than b; stop alone';
  return Case(
    key: 't',
    title: title,
    ids: const ['a/bars', 'b/bars'],
    proves: 'Two composites can share one part id; each still resolves through its own scope.',
    watch: watch,
    members: [a, b],
    toggle: () {
      final running = a.running || b.running;
      return _combine(running ? [a.stopAll(), b.stopAll()] : [a.startAll(), b.startAll()]);
    },
    start: () => _combine([a.startAll(), b.startAll()]),
    stop: () => _combine([a.stopAll(), b.stopAll()]),
    liveChains: () => [...a.liveChains, ...b.liveChains],
    box: (theme, resolver) {
      final t = resolver.tones;
      return Container(
        border: BorderType.plain,
        borderStyle: resolver.border(const {}),
        topTitles: [Line(' $title ', style: resolver.ink(t.muted))],
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Column(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxis: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PanelView(model: a, theme: theme),
                ),
                Expanded(
                  child: PanelView(model: b, theme: theme),
                ),
              ],
            ),
            Line(watch, style: resolver.ink(t.muted)),
          ],
        ),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: ECHO (e)
// ═══════════════════════════════════════════════════════════

// The panel's own id and its one part's id are both `echo`. Forwarding
// checks the segment after the panel's id first, so the part is still
// reached before the panel's own guard ever runs — the panel's own tick
// counter stays at zero.

Case _echoCase(Duration step) {
  final model = PanelModel(
    id: 'echo',
    parts: [SpinnerModel(id: 'echo', interval: step)],
  );
  const title = 'e · echo/echo';
  const watch = 'own tick counter stays 0';
  return Case(
    key: 'e',
    title: title,
    ids: const ['echo/echo'],
    proves: "A part sharing its composite's own id is still reached first, before the composite's own guard.",
    watch: watch,
    members: [model],
    toggle: () => model.running ? model.stopAll() : model.startAll(),
    start: model.startAll,
    stop: model.stopAll,
    liveChains: () => model.liveChains,
    box: (theme, resolver) => _panelBox(title, watch, model, theme),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: DUO (d)
// ═══════════════════════════════════════════════════════════

// One panel, two parts, started by a single batch: `duo/left` and
// `duo/right` are both armed by the one key that starts the panel, scoped
// together in the same call.

Case _duoCase(Duration step) {
  final model = PanelModel(
    id: 'duo',
    parts: [
      BouncerModel(id: 'left', interval: step),
      BouncerModel(id: 'right', interval: step * 3),
    ],
  );
  const title = 'd · duo/left, duo/right';
  const watch = 'one key, one batch, two parts';
  return Case(
    key: 'd',
    title: title,
    ids: const ['duo/left', 'duo/right'],
    proves: 'One key starts two parts through a single batch, scoped together in one call.',
    watch: watch,
    members: [model],
    toggle: () => model.running ? model.stopAll() : model.startAll(),
    start: model.startAll,
    stop: model.stopAll,
    liveChains: () => model.liveChains,
    box: (theme, resolver) => _panelBox(title, watch, model, theme),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: LOADER (l)
// ═══════════════════════════════════════════════════════════

// Starting this panel also asks the app for data, through a `LoadRequest`
// addressed by the panel's own id. The matching `LoadResult` arrives back
// at the same guard and stops every part — the progress bar reads `loaded`
// instead of resetting to idle.

Case _loaderCase(Duration step) {
  final model = PanelModel(
    id: 'loader',
    parts: [ProgressModel(id: 'progress', interval: step)],
    loads: true,
  );
  const title = 'l · loader/progress';
  const watch = 'fills until the load lands';
  return Case(
    key: 'l',
    title: title,
    ids: const ['loader/progress'],
    proves: "Starting asks the app for data; the matching answer stops every part by the panel's own guard.",
    watch: watch,
    members: [model],
    toggle: () => model.running ? model.stopAll() : model.startAll(),
    start: model.startAll,
    stop: model.stopAll,
    liveChains: () => model.liveChains,
    box: (theme, resolver) => _panelBox(title, watch, model, theme),
  );
}

// ═══════════════════════════════════════════════════════════
// APP MODEL
// ═══════════════════════════════════════════════════════════

/// Holds one instance of every addressing case, plus the app-level clock and
/// the HUD's counters.
///
/// [step] is the base interval every case derives its own speed from; a case
/// still picks its own multiple of it, so the derivation lives here, once,
/// rather than inside the widgets. The clock is not a case: it has no
/// component, and this model's own fall-through in [update] ticks it.
class AppModel with ThemeSwitcher {
  /// Creates the app's models. [step] and [loadDelay] default to a
  /// human-comfortable speed; a test passes a much shorter [step].
  AppModel({this.step = const Duration(milliseconds: 80), this.loadDelay = const Duration(seconds: 1)}) {
    cases = [
      _memberCase(step),
      _extraCase(step),
      _panelCase(step),
      _nestedCase(step),
      _twinsCase(step),
      _echoCase(step),
      _duoCase(step),
      _loaderCase(step),
    ];
    _byKey = {for (final c in cases) c.key: c};
    focusGroup = FocusGroup<Component>([for (final c in cases) ...c.members]);
    router = FocusRouter(focusGroup, extras: [for (final c in cases) ...c.extras]);
  }

  /// The base interval every case's own speed derives from.
  final Duration step;

  /// How long the loader case waits before its simulated fetch resolves.
  final Duration loadDelay;

  /// The app-level clock's own interval — a multiple of [step].
  Duration get clockInterval => step * 6;

  /// Whether the app-level clock's tick chain is armed.
  bool clockRunning = false;
  int _clockGeneration = 0;

  /// How many clock ticks have landed.
  int clockTicks = 0;

  /// Every addressing case, in focus order.
  late final List<Case> cases;

  late final Map<String, Case> _byKey;

  /// The flat spinner, a focus-group member — key `m`.
  AnimatedModel get member => _byKey['m']!.members.single as AnimatedModel;

  /// The bouncer reachable only through the router's extras — key `x`.
  AnimatedModel get extra => _byKey['x']!.extras.single as AnimatedModel;

  /// The panel around one spinner — keys `p` and `r`.
  PanelModel get panel => _byKey['p']!.members.single as PanelModel;

  /// The panel holding a panel, whose inner border blinks — key `n`.
  PanelModel get outer => _byKey['n']!.members.single as PanelModel;

  /// The panel whose own id and whose one part's id are both `echo` — key `e`.
  PanelModel get echo => _byKey['e']!.members.single as PanelModel;

  /// The panel that asks the app to load something when it starts — key `l`.
  PanelModel get loader => _byKey['l']!.members.single as PanelModel;

  /// Every focus-group member, drawn from every case in order.
  late final FocusGroup<Component> focusGroup;

  /// Routes keyboard, pointer and addressed traffic among the cases.
  late final FocusRouter router;

  /// The case the currently focused member belongs to.
  Case get focusedCase => cases.firstWhere((c) => c.members.contains(focusGroup.focused));

  /// How many `TickMsg`s the router delivered to a widget, plus the clock's
  /// own. Every case this example runs adds to this; it never stops growing.
  int delivered = 0;

  /// How many `TickMsg`s reached this app's fall-through addressed to
  /// something other than the clock — a misrouted tick. Stays at zero when
  /// every id-addressing rule holds.
  int dropped = 0;

  /// Every widget event the app read, in order.
  final List<WidgetEvent> events = [];

  /// The id of the last widget event this app read, or null before the
  /// first one.
  String? get lastEventId => events.isEmpty ? null : events.last.id;

  /// The id of the last panel a [PanelStartedMsg] named, or null before the
  /// first one.
  String? lastStarted;

  /// The hit path of every tick chain currently running, the clock included.
  List<String> get liveChains => [if (clockRunning) 'clock', for (final c in cases) ...c.liveChains()];
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

/// Reads a widget event the router or a case's own action produced.
///
/// Every event's [WidgetEvent.id] becomes the HUD's last-event readout,
/// recorded by the caller. This only converts a [LoadRequest] into the
/// [Task] that answers it; everything else carries no further effect.
Cmd? onEvent(AppModel model, WidgetEvent event) {
  if (event case LoadRequest(:final id, :final key)) {
    return Task(() => Future<void>.delayed(model.loadDelay), onSuccess: (_) => LoadResult<Object?>(id, key: key));
  }
  return null;
}

/// Folds one case's outcome into a runtime command, reading every event it
/// produced through [onEvent].
Cmd? _drive(AppModel model, UpdateResult result) => _driveAll(model, [result]);

/// Folds several cases' outcomes into one command, so a combined action —
/// start every case, stop every case — still resolves through a single
/// `Batch`.
Cmd? _driveAll(AppModel model, List<UpdateResult> results) {
  final cmds = <Cmd?>[];
  for (final result in results) {
    if (result is! Handled) continue;
    cmds.add(result.cmd);
    for (final event in result.events) {
      model.events.add(event);
      cmds.add(onEvent(model, event));
    }
  }
  return Batch(cmds);
}

Cmd? _toggleClock(AppModel model) {
  if (model.clockRunning) {
    model.clockRunning = false;
    return null;
  }
  model.clockRunning = true;
  model._clockGeneration++;
  return Tick(model.clockInterval, id: 'clock', key: model._clockGeneration);
}

/// The app's `update`: the router first, then the clock's own chain, then
/// one case's key, calling the method the key names on the case the app
/// holds — never a hit path spelled by hand.
(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext ctx) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  final routed = model.router.route(msg, ctx);
  if (routed is Handled) {
    if (msg is TickMsg) model.delivered++;
    return (model, _drive(model, routed));
  }

  if (msg case KeyMsg(key: 'q')) return (model, const Quit());
  if (msg case KeyMsg(key: 'c')) return (model, _toggleClock(model));

  if (msg case TickMsg(id: 'clock', :final key)) {
    if (!model.clockRunning || key != model._clockGeneration) return (model, null);
    model
      ..clockTicks += 1
      ..delivered += 1;
    return (model, Tick(model.clockInterval, id: 'clock', key: model._clockGeneration));
  }
  if (msg is TickMsg) {
    model.dropped++;
    return (model, null);
  }

  if (msg case KeyMsg(:final key)) {
    for (final c in model.cases) {
      if (key == c.key) return (model, _drive(model, c.toggle()));
    }
    if (key == 'r') return (model, _drive(model, model.panel.restartAll()));
    if (key == 'a') return (model, _driveAll(model, [for (final c in model.cases) c.start()]));
    if (key == 's') return (model, _driveAll(model, [for (final c in model.cases) c.stop()]));
  }

  if (msg case PanelStartedMsg(:final id)) {
    model.lastStarted = id;
    return (model, null);
  }

  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

View _header(StyleResolver resolver) => Line(
  'c clock · m member · x extra · p panel · r restart · n nested · t twins · e echo · d duo · l loader · '
  'a start-all · s stop-all · tab focus · enter/click toggle · F1/F2 theme · q quit',
  style: resolver.ink(resolver.tones.muted),
);

/// Two lines: the app's own state, then what the focused case proves — on
/// its own line, so a long sentence never fights the readouts for width.
View _status(AppModel model, StyleResolver resolver) {
  final muted = resolver.ink(resolver.tones.muted);
  return Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Line(
        'theme: ${model.themeName}   focus: ${model.focusGroup.focused.id}   last started: ${model.lastStarted ?? '—'}',
        style: muted,
      ),
      Line('proves: ${model.focusedCase.proves}', style: muted),
    ],
  );
}

/// Formats [model]'s clock ticks as `mm:ss.t`, from the tick count and the
/// clock's own interval — no widget holds a wall-clock timestamp.
String _formatClock(AppModel model) {
  final totalTenths = model.clockTicks * model.clockInterval.inMilliseconds ~/ 100;
  final minutes = totalTenths ~/ 600;
  final seconds = (totalTenths ~/ 10) % 60;
  final tenths = totalTenths % 10;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
}

View _clockBox(AppModel model, StyleResolver resolver) {
  final t = resolver.tones;
  return Container(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    topTitles: [Line(' c · clock ', style: resolver.ink(t.muted))],
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Line(_formatClock(model), style: model.clockRunning ? resolver.ink(t.accent) : resolver.ink(t.muted)),
        Line('no component: the app ticks this itself', style: resolver.ink(t.muted)),
      ],
    ),
  );
}

View _hud(AppModel model, Frame frame, StyleResolver resolver) {
  final t = resolver.tones;
  final chains = model.liveChains;
  return Container(
    border: BorderType.plain,
    borderStyle: resolver.ink(t.muted),
    topTitles: [Line(' hud ', style: resolver.ink(t.muted))],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Line(
          'delivered ${model.delivered}   dropped ${model.dropped}   '
          'last event ${model.lastEventId ?? '—'}   cells ${frame.lastDiffCount}',
          style: resolver.ink(t.accent),
        ),
        Line('live: ${chains.isEmpty ? '—' : chains.join(', ')}', style: resolver.ink(t.muted)),
      ],
    ),
  );
}

/// The app's `view`: a header, a grid of one box per case plus the clock, a
/// status line, and the HUD row.
void view(AppModel model, Frame frame) {
  final theme = model.theme;
  final resolver = StyleResolver(theme);
  final t = resolver.tones;
  frame.buffer.setStyle(frame.area, resolver.ground(t.background));

  final boxes = {for (final c in model.cases) c.key: c.box(theme, resolver)};

  final grid = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _clockBox(model, resolver)),
            Expanded(child: boxes['m']!),
            Expanded(child: boxes['x']!),
            Expanded(child: boxes['p']!),
            Expanded(child: boxes['e']!),
          ],
        ),
      ),
      const SizedBox(height: 1),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: boxes['n']!),
            Expanded(child: boxes['t']!),
            Expanded(child: boxes['d']!),
            Expanded(child: boxes['l']!),
          ],
        ),
      ),
    ],
  );

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      _header(resolver),
      const SizedBox(height: 1),
      Expanded(child: grid),
      const SizedBox(height: 1),
      _status(model, resolver),
      _hud(model, frame, resolver),
    ],
  );

  frame.render(ui);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Animation addressing stress test', mouseEvents: true).run(
      init: AppModel(),
      update: update,
      view: view,
    ),
  );
}
