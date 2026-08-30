// Every id-addressing rule the framework has, run under stress at once: a
// flat spinner, one reachable only through `extras`, a panel around one
// spinner, a panel inside a panel, twin panels that both name a part
// `spinner`, a panel and its own part sharing one id, a panel with two parts
// started by a single batch, a restart with a bumped generation, and a panel
// that asks the app to load something and stops itself once the answer
// lands.
//
// c clock · m member · x extra · p panel · r restart panel · n nested ·
// t twins · e echo · d duo · l loader · a start all · s stop all ·
// tab focus · enter/click toggle a spinner · F1/F2 theme · q quit

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

const List<String> _defaultFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

// ═══════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════

/// Emitted when a spinner's running state toggles — by Enter or by a click
/// alike. Addresses the spinner by [id].
class SpinnerToggleEvent extends WidgetEvent {
  /// Creates the event carrying the spinner's [id] and its [running] state
  /// right after the toggle.
  const SpinnerToggleEvent(this.id, {required this.running});

  /// The id of the spinner that toggled.
  @override
  final String id;

  /// Whether the spinner is running after the toggle.
  final bool running;
}

/// Emitted when a panel's part toggles, in place of the part's own event.
///
/// A [PanelModel] never lets a part's event through unchanged: it reads the
/// part's own toggle and re-addresses it as one of these, naming itself as
/// [id] and the part as [part]. A panel nested inside another panel is
/// re-addressed again the same way, so the app only ever sees ids it
/// registered with its [FocusRouter].
class PanelToggleEvent extends WidgetEvent {
  /// Creates the event: the panel's own [id], the [part] that toggled, and
  /// its [running] state right after the toggle.
  const PanelToggleEvent(this.id, {required this.part, required this.running});

  /// The id of the panel that produced this event.
  @override
  final String id;

  /// The bare id of the part that toggled — a spinner's own id, or a nested
  /// panel's own id.
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
// SPINNER MODEL
// ═══════════════════════════════════════════════════════════

/// A spinner: a running flag, a frame index, and a generation that guards its
/// own tick chain.
///
/// [start], [stop] and [restart] are the control surface a panel or the app
/// drives directly. Enter while focused, and a pointer press on the
/// spinner's own cells, both go through [update] instead and toggle it the
/// same way, emitting [SpinnerToggleEvent]. A spinner always arms its tick
/// with its own bare [id] — never the path it may have arrived under —
/// because a spinner has no way to know what, if anything, wraps it.
class SpinnerModel implements Component {
  /// Creates a spinner with its own [id] and tick [interval]. [frames] is the
  /// glyph cycle the view paints; it defaults to a braille spinner.
  SpinnerModel({required this.id, this.interval = const Duration(milliseconds: 80), List<String>? frames})
    : frames = frames ?? _defaultFrames;

  @override
  final String id;

  /// How long the spinner waits between frames.
  final Duration interval;

  /// The glyphs the spinner cycles through while running.
  final List<String> frames;

  /// The index into [frames] the view is showing.
  int frameIndex = 0;

  /// Whether the spinner's tick chain is armed.
  bool running = false;

  /// The running tick chain's generation. [start] and [restart] bump it, so a
  /// tick armed before either lands stale and is not re-armed.
  int generation = 0;

  bool _focused = false;

  /// Whether the spinner owns keyboard input.
  bool get focused => _focused;

  @override
  set focused(bool value) => _focused = value;

  /// The glyph the view paints for the current frame.
  String get glyph => frames[frameIndex % frames.length];

  /// Arms the tick chain, or does nothing if it is already running.
  Cmd? start() {
    if (running) return null;
    running = true;
    generation++;
    return Tick(interval, id: id, key: generation);
  }

  /// Stops the tick chain. A tick already in flight lands, finds [running]
  /// false, and is not re-armed.
  Cmd? stop() {
    running = false;
    return null;
  }

  /// Stops the current chain, if any, and arms a fresh one with a bumped
  /// [generation] — unlike [start], this always re-arms, running or not.
  Cmd? restart() {
    running = true;
    generation++;
    return Tick(interval, id: id, key: generation);
  }

  /// Handles a message, reporting whether it was consumed and what it
  /// produced.
  ///
  /// A pointer press on the spinner's own cells toggles it above the focus
  /// gate; every other pointer message on them is consumed with no effect,
  /// since the spinner tracks no hover or capture state. A pointer whose path
  /// does not end in this spinner's id is declined. A [TickMsg] whose leaf names this spinner
  /// advances [frameIndex] and re-arms when [running] and the key matches
  /// [generation]; a stale or stopped tick is consumed but not re-armed.
  /// Enter toggles the spinner while focused. Everything else is declined.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) {
      if (pointer.isWheel) return const Declined();
      // A pointer is this spinner's only when its path ends in this id.
      if (pointer.targetId case final target? when HitTag.leafOf(target) == id) {
        return pointer.isDown ? _toggle() : const Handled();
      }
      return const Declined();
    }
    if (msg is PointerLeaveMsg || msg is PointerCancelMsg) return const Declined();

    if (msg case TickMsg(id: final path, :final key) when HitTag.leafOf(path) == id) {
      if (!running || key != generation) return const Handled();
      frameIndex = (frameIndex + 1) % frames.length;
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
// SPINNER VIEW
// ═══════════════════════════════════════════════════════════

/// The render half of a [SpinnerModel]: one line of text, self-tagged with
/// the model's id.
final class SpinnerView implements View {
  /// Creates a spinner view over [model], styled by [theme].
  const SpinnerView({required this.model, required this.theme});

  /// The model whose glyph and running state this view paints.
  final SpinnerModel model;

  /// The theme that resolves the spinner's ink.
  final Theme theme;

  @override
  Node build() {
    final resolver = StyleResolver(theme);
    final t = resolver.tones;
    final style = model.running ? resolver.ink(t.accent) : resolver.ink(t.muted);
    final glyph = model.running ? model.glyph : '·';
    return Line('$glyph ${model.id}', style: style).build()..tag = IdTag(model.id);
  }
}

// ═══════════════════════════════════════════════════════════
// PANEL MODEL
// ═══════════════════════════════════════════════════════════

/// A composite that embeds a fixed list of parts — each a [SpinnerModel] or a
/// nested [PanelModel] — and forwards to the one a delivered path names.
///
/// [startAll], [stopAll] and [restartAll] drive every part at once through
/// one command, scoped so a part's `Tick` reaches it again after one more
/// hop outward. Interactive traffic — Enter, or a click on a part — reaches
/// [update] instead: a part's own [SpinnerToggleEvent] or [PanelToggleEvent]
/// is always re-addressed as a [PanelToggleEvent] naming this panel, never
/// let through unchanged. A panel with [blinkInterval] set also owns one tick
/// chain of its own — its border's blink — armed with its own bare [id]. A
/// panel with [loads] set asks the app for data when it starts, through a
/// [LoadRequest], and stops every part once the matching [LoadResult] lands.
class PanelModel implements Component {
  /// Creates a panel over [parts], keyed by their own bare id. [blinkInterval]
  /// gives the panel's own border a blink; leave it null for a panel with no
  /// blink of its own. [loads] makes [startAll] also ask the app to load
  /// something, addressed by this panel's own [id].
  PanelModel({required this.id, required this.parts, this.blinkInterval, this.loads = false});

  @override
  final String id;

  /// This panel's parts, in the order [update] tries them for a keystroke.
  final List<Component> parts;

  /// How often this panel's own border blinks, or null for no blink.
  final Duration? blinkInterval;

  /// Whether starting this panel also asks the app to load something,
  /// addressed by this panel's own [id].
  final bool loads;

  late final Map<String, Component> _byId = {for (final part in parts) part.id: part};

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

  /// Whether any part is running, this panel's own blink is on, or a load it
  /// asked for is in flight.
  bool get running =>
      loading ||
      _blinkRunning ||
      parts.any(
        (part) => switch (part) {
          final SpinnerModel s => s.running,
          final PanelModel p => p.running,
          _ => false,
        },
      );

  /// The hit path of every tick chain currently running under this panel,
  /// its own blink included.
  List<String> get liveChains => [
    if (_blinkRunning) id,
    for (final part in parts)
      for (final chain in switch (part) {
        final SpinnerModel s when s.running => [s.id],
        final PanelModel p => p.liveChains,
        _ => const <String>[],
      })
        HitTag.join(id, chain),
  ];

  /// Starts every part, and this panel's own blink if it has one, through one
  /// command. A panel already fully running is a safe no-op: every part call
  /// is idempotent, so re-pressing the key that starts an already-running
  /// case starts nothing twice. When [loads], also asks the app for data with
  /// a freshly bumped generation. The batch always carries one non-tick
  /// [PanelStartedMsg], so the scoping helper's pass-through stays visible
  /// next to the parts' ticks.
  UpdateResult startAll() {
    final cmds = <Cmd?>[for (final part in parts) _scopedStart(part), _startBlink()];
    final events = <WidgetEvent>[];
    if (loads && !loading) {
      loading = true;
      _loadGeneration++;
      events.add(LoadRequest(id, key: _loadGeneration));
    }
    cmds.add(Emit(PanelStartedMsg(id)));
    return Handled(events: events, cmd: Batch(cmds));
  }

  /// Stops every part, and this panel's own blink, through one command.
  UpdateResult stopAll() {
    final cmds = <Cmd?>[for (final part in parts) _scopedStop(part), _stopBlink()];
    loading = false;
    return Handled(cmd: Batch(cmds));
  }

  /// Restarts every part with a bumped generation, and re-arms this panel's
  /// own blink the same way, whether or not either was already running.
  UpdateResult restartAll() {
    final cmds = <Cmd?>[for (final part in parts) _scopedRestart(part)];
    final interval = blinkInterval;
    if (interval != null) {
      _blinkRunning = true;
      _blinkGeneration++;
      cmds.add(Tick(interval, id: id, key: _blinkGeneration));
    }
    return Handled(cmd: Batch(cmds));
  }

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
    loading = false;
    return Handled(cmd: Batch([for (final part in parts) _scopedStop(part)]));
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

  Cmd? _scopedStart(Component part) => _scopeCmd(
    switch (part) {
      final SpinnerModel s => s.start(),
      final PanelModel p => (p.startAll() as Handled).cmd,
      _ => null,
    },
  );

  Cmd? _scopedStop(Component part) => _scopeCmd(
    switch (part) {
      final SpinnerModel s => s.stop(),
      final PanelModel p => (p.stopAll() as Handled).cmd,
      _ => null,
    },
  );

  Cmd? _scopedRestart(Component part) => _scopeCmd(
    switch (part) {
      final SpinnerModel s => s.restart(),
      final PanelModel p => (p.restartAll() as Handled).cmd,
      _ => null,
    },
  );

  Cmd? _scopeCmd(Cmd? cmd) => switch (Handled(cmd: cmd).scopeTicks(id)) {
    Handled(:final cmd) => cmd,
    Declined() => null,
  };
}

// ═══════════════════════════════════════════════════════════
// PANEL VIEW
// ═══════════════════════════════════════════════════════════

/// The render half of a [PanelModel]: a bordered box around its parts,
/// scoped under the model's id. [title] overrides the border's title —
/// nested calls leave it null and show the model's bare id instead.
final class PanelView implements View {
  /// Creates a panel view over [model], styled by [theme].
  const PanelView({required this.model, required this.theme, this.title});

  /// The model whose parts and blink state this view paints.
  final PanelModel model;

  /// The theme that resolves the panel's chrome.
  final Theme theme;

  /// The border's title, or null to show the model's bare id.
  final String? title;

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
          children: [for (final part in model.parts) _partView(part, theme)],
        ),
      ),
    ).build();
  }
}

View _partView(Component part, Theme theme) => switch (part) {
  final SpinnerModel s => SpinnerView(model: s, theme: theme),
  final PanelModel p => PanelView(model: p, theme: theme),
  _ => const SizedBox(),
};

// ═══════════════════════════════════════════════════════════
// APP MODEL
// ═══════════════════════════════════════════════════════════

/// Holds one instance of every addressing case from the table above, plus the
/// app-level clock and the HUD's counters.
///
/// [step] is the base interval every case derives its own speed from; every
/// [SpinnerModel] and [PanelModel] still takes its own interval, so the
/// derivation lives here, once, rather than inside the widgets.
class AppModel with ThemeSwitcher {
  /// Creates the app's models. [step] and [loadDelay] default to a
  /// human-comfortable speed; a test passes a much shorter [step].
  AppModel({this.step = const Duration(milliseconds: 80), this.loadDelay = const Duration(seconds: 1)});

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

  /// The flat spinner, a focus-group member — key `m`.
  late final SpinnerModel member = SpinnerModel(id: 'member', interval: step);

  /// The spinner reachable only through the router's `extras` — key `x`.
  late final SpinnerModel extra = SpinnerModel(id: 'extra', interval: step);

  /// The panel around one spinner — keys `p` and `r`.
  late final PanelModel panel = PanelModel(
    id: 'panel',
    parts: [SpinnerModel(id: 'spinner', interval: step)],
  );

  /// The panel holding a panel, whose inner border blinks — key `n`.
  late final PanelModel outer = PanelModel(
    id: 'outer',
    parts: [
      PanelModel(
        id: 'inner',
        parts: [SpinnerModel(id: 'spinner', interval: step)],
        blinkInterval: step * 10,
      ),
    ],
  );

  /// The left twin panel, part of the two-panel `t` case.
  late final PanelModel twinA = PanelModel(
    id: 'a',
    parts: [SpinnerModel(id: 'spinner', interval: step)],
  );

  /// The right twin panel, part of the two-panel `t` case.
  late final PanelModel twinB = PanelModel(
    id: 'b',
    parts: [SpinnerModel(id: 'spinner', interval: step * 2)],
  );

  /// The panel whose own id and whose one part's id are both `echo` — key `e`.
  late final PanelModel echo = PanelModel(
    id: 'echo',
    parts: [SpinnerModel(id: 'echo', interval: step)],
  );

  /// The panel with two spinners started by one batch — key `d`.
  late final PanelModel duo = PanelModel(
    id: 'duo',
    parts: [
      SpinnerModel(id: 'left', interval: step),
      SpinnerModel(id: 'right', interval: step * 3),
    ],
  );

  /// The panel that asks the app to load something when it starts — key `l`.
  late final PanelModel loader = PanelModel(
    id: 'loader',
    parts: [SpinnerModel(id: 'spinner', interval: step)],
    loads: true,
  );

  /// Every focus-group member: the flat spinner and every panel.
  late final FocusGroup<Component> focusGroup = FocusGroup<Component>([
    member,
    panel,
    outer,
    twinA,
    twinB,
    echo,
    duo,
    loader,
  ]);

  /// Routes keyboard, pointer and addressed traffic among [focusGroup] and
  /// [extra].
  late final FocusRouter router = FocusRouter(focusGroup, extras: [extra]);

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
  List<String> get liveChains => [
    if (clockRunning) 'clock',
    if (member.running) member.id,
    if (extra.running) extra.id,
    ...panel.liveChains,
    ...outer.liveChains,
    ...twinA.liveChains,
    ...twinB.liveChains,
    ...echo.liveChains,
    ...duo.liveChains,
    ...loader.liveChains,
  ];
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
    return Task(
      () => Future<void>.delayed(model.loadDelay),
      onSuccess: (_) => LoadResult<Object?>(id, key: key),
    );
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

Cmd? _toggleSpinner(AppModel model, SpinnerModel spinner) =>
    _drive(model, Handled(cmd: spinner.running ? spinner.stop() : spinner.start()));

Cmd? _togglePanel(AppModel model, PanelModel panel) =>
    _drive(model, panel.running ? panel.stopAll() : panel.startAll());

Cmd? _toggleTwins(AppModel model) {
  final running = model.twinA.running || model.twinB.running;
  return _driveAll(
    model,
    running ? [model.twinA.stopAll(), model.twinB.stopAll()] : [model.twinA.startAll(), model.twinB.startAll()],
  );
}

Cmd? _startEverything(AppModel model) => _driveAll(model, [
  Handled(cmd: model.member.start()),
  Handled(cmd: model.extra.start()),
  model.panel.startAll(),
  model.outer.startAll(),
  model.twinA.startAll(),
  model.twinB.startAll(),
  model.echo.startAll(),
  model.duo.startAll(),
  model.loader.startAll(),
]);

Cmd? _stopEverything(AppModel model) => _driveAll(model, [
  Handled(cmd: model.member.stop()),
  Handled(cmd: model.extra.stop()),
  model.panel.stopAll(),
  model.outer.stopAll(),
  model.twinA.stopAll(),
  model.twinB.stopAll(),
  model.echo.stopAll(),
  model.duo.stopAll(),
  model.loader.stopAll(),
]);

/// The app's `update`: the router first, then the clock's own chain, then
/// the single-letter case keys, calling the method the case's key names on
/// the model the app holds — never a hit path spelled by hand.
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

  if (msg case KeyMsg(key: 'm')) return (model, _toggleSpinner(model, model.member));
  if (msg case KeyMsg(key: 'x')) return (model, _toggleSpinner(model, model.extra));
  if (msg case KeyMsg(key: 'p')) return (model, _togglePanel(model, model.panel));
  if (msg case KeyMsg(key: 'r')) return (model, _drive(model, model.panel.restartAll()));
  if (msg case KeyMsg(key: 'n')) return (model, _togglePanel(model, model.outer));
  if (msg case KeyMsg(key: 't')) return (model, _toggleTwins(model));
  if (msg case KeyMsg(key: 'e')) return (model, _togglePanel(model, model.echo));
  if (msg case KeyMsg(key: 'd')) return (model, _togglePanel(model, model.duo));
  if (msg case KeyMsg(key: 'l')) return (model, _togglePanel(model, model.loader));
  if (msg case KeyMsg(key: 'a')) return (model, _startEverything(model));
  if (msg case KeyMsg(key: 's')) return (model, _stopEverything(model));

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

View _status(AppModel model, StyleResolver resolver) => Line(
  'theme: ${model.themeName}   focus: ${model.focusGroup.focused.id}   last started: ${model.lastStarted ?? '—'}',
  style: resolver.ink(resolver.tones.muted),
);

View _clockBox(AppModel model, StyleResolver resolver) {
  final t = resolver.tones;
  final glyph = model.clockRunning ? _defaultFrames[model.clockTicks % _defaultFrames.length] : '·';
  return Container(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    topTitles: [Line(' c · clock ', style: resolver.ink(t.muted))],
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: Line('$glyph clock', style: model.clockRunning ? resolver.ink(t.accent) : resolver.ink(t.muted)),
  );
}

View _spinnerBox(String label, SpinnerModel model, Theme theme, StyleResolver resolver) => Container(
  border: BorderType.plain,
  borderStyle: resolver.border({if (model.focused) WidgetState.focused}),
  topTitles: [Line(' $label ', style: resolver.ink(resolver.tones.muted))],
  padding: const EdgeInsets.symmetric(horizontal: 1),
  child: SpinnerView(model: model, theme: theme),
);

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

/// The app's `view`: a header, a grid of one box per addressing case, a
/// status line, and the HUD row.
void view(AppModel model, Frame frame) {
  final theme = model.theme;
  final resolver = StyleResolver(theme);
  final t = resolver.tones;
  frame.buffer.setStyle(frame.area, resolver.ground(t.background));

  final grid = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _clockBox(model, resolver)),
            Expanded(child: _spinnerBox('m · member', model.member, theme, resolver)),
            Expanded(child: _spinnerBox('x · extra', model.extra, theme, resolver)),
            Expanded(
              child: PanelView(model: model.panel, theme: theme, title: 'p/r · panel/spinner'),
            ),
            Expanded(
              child: PanelView(model: model.echo, theme: theme, title: 'e · echo/echo'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 1),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: PanelView(model: model.outer, theme: theme, title: 'n · outer/inner/spinner'),
            ),
            Expanded(
              child: PanelView(model: model.twinA, theme: theme, title: 't · a/spinner'),
            ),
            Expanded(
              child: PanelView(model: model.twinB, theme: theme, title: 't · b/spinner'),
            ),
            Expanded(
              child: PanelView(model: model.duo, theme: theme, title: 'd · duo/left,right'),
            ),
            Expanded(
              child: PanelView(model: model.loader, theme: theme, title: 'l · loader/spinner'),
            ),
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
