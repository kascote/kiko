import 'package:meta/meta.dart';

import 'ansi16_tones.dart';
import 'cell.dart';
import 'colors.dart';
import 'style.dart';
import 'theme.dart';
import 'tone.dart';
import 'widget_state.dart';

/// How a tone lands as paint on a given part.
///
/// States pick tones; the call site picks a paint class. The same tone through
/// two classes is how a selected pane border ([ink]) and a selected row
/// ([fill]) share one color without the border dragging a background.
enum PaintClass {
  /// Foreground only — line glyphs, separators, accent text.
  ink,

  /// A filled surface — the tone's `on` over its `color` — selected rows,
  /// button faces.
  fill,

  /// Background only — tints existing content, preserving its foreground.
  wash,
}

/// Whether the resolver may use color, must re-express meaning without it, or
/// must re-express it through a fixed 16-color palette.
///
/// Under [noColor] (a `NO_COLOR` terminal) color fidelity is not a downgrade
/// but a *semantic* gap: a selection whose whole identity is its background
/// becomes invisible, not merely dimmer. The re-expression happens here, at the
/// projection — the one place that still knows the intent — so widgets never
/// know: a `fill` degrades to [Modifier.reversed], an `ink` keeps its modifiers
/// but drops its foreground, and a `wash` (a tint that cannot exist without
/// color) degrades to nothing. No state layer lifts a color; focus adds bold,
/// pressed toggles [Modifier.reversed] and de-emphasis adds [Modifier.dim].
///
/// Under [ansi16] color survives, but only through sixteen named slots
/// instead of free RGB: `ink`/`fill` paint through the [Ansi16Tones] table
/// derived from the theme ([Ansi16Tones.derive]) instead of its RGB tones, and
/// a `wash` still drops entirely — the 16-name vocabulary has no subtle tints
/// to spend on one. A state-layer lift becomes the bright variant of the color it lifts, and
/// de-emphasis adds [Modifier.dim].
enum RenderPolicy {
  /// Colors render as themed, in full RGB.
  color,

  /// Colors are dropped; meaning survives through modifiers alone.
  noColor,

  /// Colors render through the theme's named ANSI-16 table instead of RGB;
  /// washes drop, same as [noColor].
  ansi16,
}

/// Resolves a [Style] from a [Theme], active [WidgetState]s, and a [PaintClass],
/// on one ground.
///
/// The resolver is bound to a ground: the [SurfaceTone] its parts sit on,
/// [tones].background by default. Every lift, blend and tint it computes starts
/// from that ground. Call [on] to bind another ground, such as
/// [ToneSet.surface] for a dialog, and hand the result to the views the dialog
/// holds. A widget then looks the same inside the dialog as outside it.
///
/// A widget calls [resolve] once per part with that part's base style, its
/// states and a [PaintClass]. [resolve] applies the state layers in one fixed
/// order, whatever the class: roles ([WidgetState.selected],
/// [WidgetState.loading], [WidgetState.error]), then [WidgetState.focused],
/// [WidgetState.cursor], [WidgetState.disabled], [WidgetState.hover],
/// [WidgetState.pressed], and last de-emphasis. A lift moves a background by
/// [Theme.step] in OKLab lightness, away from the ground. The ink class never
/// lifts.
///
/// ```dart
/// final resolver = StyleResolver(theme);
/// final rowStyle = resolver.resolve(null, {WidgetState.selected}, cls: PaintClass.fill);
/// final borderStyle = resolver.border({if (m.focused) WidgetState.focused});
/// final inDialog = resolver.on(resolver.tones.surface);
/// ```
///
/// [deEmphasised] returns a resolver whose every projection is quieter, for a
/// pane that is present but not the one being used.
@immutable
class StyleResolver {
  /// The process-wide policy new resolvers adopt when none is passed.
  ///
  /// A `NO_COLOR` fact is set once, at startup, for the whole process, and the
  /// theme is app-owned — so widgets construct `StyleResolver(theme)` without
  /// threading a policy through. `Application` sets this from the terminal's
  /// color profile before the first frame; tests that need a specific policy
  /// pass [policy] explicitly or set this directly.
  static RenderPolicy defaultPolicy = RenderPolicy.color;

  /// Creates a resolver backed by [theme], bound to the theme's background.
  ///
  /// [policy] defaults to [defaultPolicy] (the process-wide value set by
  /// `Application` from the terminal profile), so a widget never has to know or
  /// pass it. The theme must carry a background color.
  factory StyleResolver(Theme theme, {RenderPolicy? policy}) {
    assert(theme.background.color != null, 'A theme must carry a background color.');
    final resolved = policy ?? defaultPolicy;
    final tones = _tonesFor(theme, resolved);
    return StyleResolver._(theme, resolved, tones, tones.background, isDeEmphasised: false);
  }

  const StyleResolver._(this.theme, this.policy, this.tones, this.groundTone, {required this.isDeEmphasised});

  static ToneSet _tonesFor(Theme theme, RenderPolicy policy) =>
      policy == RenderPolicy.ansi16 ? Ansi16Tones.derive(theme) : theme;

  /// The theme used for built-in state defaults.
  final Theme theme;

  /// How tones become paint — full color, the [RenderPolicy.noColor]
  /// modifier-only re-expression, or the [RenderPolicy.ansi16] named palette.
  final RenderPolicy policy;

  /// The tone set every projection reads from.
  ///
  /// [theme] itself under [RenderPolicy.color] and [RenderPolicy.noColor];
  /// under [RenderPolicy.ansi16] this is the [Ansi16Tones] table derived once
  /// and cached. Resolved a single time at construction. Read a tone to project
  /// or to pass to [on] from here, never from [theme].
  final ToneSet tones;

  /// The ground this resolver's parts sit on.
  ///
  /// Lifts move away from its color, a disabled fill and a de-emphasised part
  /// blend toward it, and a part with no background of its own starts from it.
  final SurfaceTone groundTone;

  /// Whether this resolver quiets everything it hands out.
  ///
  /// See [deEmphasised].
  final bool isDeEmphasised;

  /// This resolver rebound to [ground]; the de-emphasis flag carries over.
  ///
  /// Pass a tone read from [tones], such as `tones.surface`, so it matches the
  /// render policy. [ground] must carry a color.
  StyleResolver on(SurfaceTone ground) {
    assert(ground.color != null, 'A ground must carry a color.');
    return StyleResolver._(theme, policy, tones, ground, isDeEmphasised: isDeEmphasised);
  }

  /// This resolver with de-emphasis on; the ground carries over.
  ///
  /// Every projection ([ink], [fill], [wash], [ground]) and every [resolve]
  /// result is quieter. Under [RenderPolicy.color] each color moves toward the
  /// ground by [Theme.deEmphasis]; under [RenderPolicy.ansi16] and
  /// [RenderPolicy.noColor] the style gains [Modifier.dim]. A pane hands this
  /// resolver to the views it holds while it is not the active one.
  ///
  /// [resolve] does not touch its `base`, so build the base from this
  /// resolver's own projections. A raw style passed as `base` stays as bright
  /// as it is.
  StyleResolver get deEmphasised => StyleResolver._(theme, policy, tones, groundTone, isDeEmphasised: true);

  Color get _groundColor => groundTone.color!;

  /// Resolves a [Style] by applying state layers on top of [base].
  ///
  /// [base] is the part's resting style. When it is null the start is the
  /// background of `ground(groundTone)` in [PaintClass.fill], with no
  /// foreground, so the text color stays the area's; in the other classes it
  /// is an empty style. With no [states] the start comes back unchanged.
  ///
  /// The layers apply in this order, for every class:
  ///
  /// 1. Roles, in the order [WidgetState.selected], [WidgetState.loading],
  ///    [WidgetState.error]. Each patches a tone: ink uses the primary tone
  ///    for selected and the error tone for error, fill and wash use the
  ///    selection and error tones. Loading adds the warning ink and a slow
  ///    blink in ink and fill, and nothing in wash.
  /// 2. [WidgetState.focused]. Ink class: the primary ink, unless a role
  ///    already set one, plus bold. Fill class: a lift of one [Theme.step]
  ///    plus bold. Wash class: nothing.
  /// 3. [WidgetState.cursor]. Fill and wash classes: a lift of one step.
  ///    A fill that is also focused lifts once, not twice. Under
  ///    [RenderPolicy.noColor] a cursor fill adds bold instead, since
  ///    nothing lifts. Ink class: nothing.
  /// 4. [WidgetState.disabled] ends the chain, so hover and pressed do not
  ///    apply. Ink class and a bare fill: the disabled ink plus dim. A
  ///    filled result under [RenderPolicy.color]: both halves blend toward
  ///    the ground by [Theme.disabledMix] plus dim. A background that marks
  ///    a position, from [WidgetState.cursor] or [WidgetState.focused] or a
  ///    result with no `fg`, keeps its color and only the ink blends. Other
  ///    policies add dim alone. Wash class: nothing.
  /// 5. [WidgetState.hover]. Fill and wash classes: a lift of half a step.
  ///    Nothing in ink class or under [RenderPolicy.noColor].
  /// 6. [WidgetState.pressed]. Fill and wash classes: a lift of one step on
  ///    top of hover. Under [RenderPolicy.noColor] it toggles
  ///    [Modifier.reversed]. Nothing in ink class.
  /// 7. De-emphasis, on a resolver from [deEmphasised]. See there.
  ///
  /// A lift moves the background of the result, or the ground color when the
  /// result has none, by a [Theme.step] fraction in OKLab lightness: lighter
  /// on a dark ground, darker on a light one. Under [RenderPolicy.ansi16] it
  /// becomes the bright variant. Under [RenderPolicy.noColor] no color
  /// moves.
  ///
  /// [cls] names the paint class the call site paints — the part picks the
  /// projection, so there is no default. [slots] carries per-state authored
  /// styles. A slot for an active state replaces that state's layer: the slot
  /// style is patched onto the result and the layer adds nothing else, no
  /// bold, no lift, no dim. A slot for [WidgetState.disabled] still ends the
  /// chain. A slot for a state that is not active is ignored. On a
  /// de-emphasised resolver a slot style is blended first.
  Style resolve(
    Style? base,
    Set<WidgetState> states, {
    required PaintClass cls,
    Map<WidgetState, Style> slots = const {},
  }) {
    final start = base ?? (cls == PaintClass.fill ? Style(bg: ground(groundTone).bg) : const Style());
    return _dimOutsideColor(_applyLayers(start, states, cls, slots));
  }

  Style _applyLayers(Style start, Set<WidgetState> states, PaintClass cls, Map<WidgetState, Style> slots) {
    if (states.isEmpty) return start;

    var result = _applyRoles(start, states, cls, slots);
    if (states.contains(WidgetState.focused)) result = _applyFocused(result, states, cls, slots);
    if (states.contains(WidgetState.cursor)) result = _applyCursor(result, states, cls, slots);
    if (states.contains(WidgetState.disabled)) return _applyDisabled(result, states, cls, slots);
    if (states.contains(WidgetState.hover)) {
      result = _layer(result, slots[WidgetState.hover], () => _liftIn(result, cls, Theme.step / 2));
    }
    if (states.contains(WidgetState.pressed)) {
      result = _layer(result, slots[WidgetState.pressed], () => _applyPressed(result, cls));
    }
    return result;
  }

  /// Patches the authored [slot] when there is one, else the built-in
  /// [layer] result.
  Style _layer(Style result, Style? slot, Style Function() layer) =>
      slot == null ? layer() : result.patch(_quietSlot(slot));

  Style _applyRoles(Style start, Set<WidgetState> states, PaintClass cls, Map<WidgetState, Style> slots) {
    var result = start;
    for (final state in _roleStates) {
      if (!states.contains(state)) continue;
      final contribution = slots[state];
      result = result.patch(contribution == null ? _role(state, cls) : _quietSlot(contribution));
    }
    return result;
  }

  /// The states that pick a role, in the order [resolve] applies them.
  static const List<WidgetState> _roleStates = [WidgetState.selected, WidgetState.loading, WidgetState.error];

  /// The style a role [state] contributes for [cls].
  Style _role(WidgetState state, PaintClass cls) => switch (state) {
    WidgetState.selected => _selectedRole(cls),
    WidgetState.loading => _loadingRole(cls),
    WidgetState.error => _errorRole(cls),
    _ => const Style(),
  };

  Style _selectedRole(PaintClass cls) => switch (cls) {
    PaintClass.ink => ink(tones.primary),
    PaintClass.fill => fill(tones.selection),
    PaintClass.wash => wash(tones.selection),
  };

  Style _loadingRole(PaintClass cls) => switch (cls) {
    PaintClass.ink || PaintClass.fill => ink(tones.warning).incModifier(Modifier.slowBlink),
    PaintClass.wash => const Style(),
  };

  Style _errorRole(PaintClass cls) => switch (cls) {
    PaintClass.ink => ink(tones.error),
    PaintClass.fill => fill(tones.error),
    PaintClass.wash => wash(tones.error),
  };

  Style _applyFocused(Style result, Set<WidgetState> states, PaintClass cls, Map<WidgetState, Style> slots) {
    final slot = slots[WidgetState.focused];
    if (slot != null) return result.patch(_quietSlot(slot));
    switch (cls) {
      case PaintClass.ink:
        final hasRole = _roleStates.any(states.contains);
        return (hasRole ? result : result.patch(ink(tones.primary))).incModifier(Modifier.bold);
      case PaintClass.fill:
        return _liftBg(result, Theme.step).incModifier(Modifier.bold);
      case PaintClass.wash:
        return result;
    }
  }

  Style _applyCursor(Style result, Set<WidgetState> states, PaintClass cls, Map<WidgetState, Style> slots) {
    final slot = slots[WidgetState.cursor];
    if (slot != null) return result.patch(_quietSlot(slot));
    if (cls == PaintClass.ink) return result;
    // A focused fill has already taken the cursor's step.
    final lifted = cls == PaintClass.fill && states.contains(WidgetState.focused) && slots[WidgetState.focused] == null;
    final moved = lifted ? result : _liftBg(result, Theme.step);
    // With no color to lift, bold is the only mark a cursor fill can leave.
    final mark = policy == RenderPolicy.noColor && cls == PaintClass.fill;
    return mark ? moved.incModifier(Modifier.bold) : moved;
  }

  Style _applyDisabled(Style result, Set<WidgetState> states, PaintClass cls, Map<WidgetState, Style> slots) {
    final slot = slots[WidgetState.disabled];
    if (slot != null) return result.patch(_quietSlot(slot));
    switch (cls) {
      case PaintClass.wash:
        return result;
      case PaintClass.ink:
        return result.patch(ink(tones.disabled)).incModifier(Modifier.dim);
      case PaintClass.fill:
        return _disabledFill(result, states);
    }
  }

  Style _disabledFill(Style result, Set<WidgetState> states) {
    final bg = result.bg;
    if (_isBare(bg)) return result.patch(ink(tones.disabled)).incModifier(Modifier.dim);
    if (policy != RenderPolicy.color) return result.incModifier(Modifier.dim);

    final ground = _groundColor;
    final fg = result.fg;
    final positional = fg == null || states.contains(WidgetState.cursor) || states.contains(WidgetState.focused);
    return result
        .copyWith(
          fg: fg == null ? ink(tones.disabled).fg : fg.mix(ground, Theme.disabledMix),
          bg: positional ? bg : bg!.mix(ground, Theme.disabledMix),
        )
        .incModifier(Modifier.dim);
  }

  Style _applyPressed(Style result, PaintClass cls) {
    if (cls == PaintClass.ink) return result;
    if (policy != RenderPolicy.noColor) return _liftBg(result, Theme.step);
    return result.addModifier.has(Modifier.reversed)
        ? result.removeModifier(Modifier.reversed)
        : result.incModifier(Modifier.reversed);
  }

  Style _liftIn(Style result, PaintClass cls, double amount) =>
      cls == PaintClass.ink ? result : _liftBg(result, amount);

  static bool _isBare(Color? bg) => bg == null || bg == Color.reset;

  /// Lifts the background of [result] by [amount], or the ground color when
  /// [result] has none. Under [RenderPolicy.noColor] nothing can lift.
  ///
  /// A de-emphasised resolver under color lifts by the share of [amount] that
  /// is left after [Theme.deEmphasis], so a lift is as quiet as the rest.
  Style _liftBg(Style result, double amount) {
    if (policy == RenderPolicy.noColor) return result;
    final quiet = isDeEmphasised && policy == RenderPolicy.color;
    final step = quiet ? amount * (1 - theme.deEmphasis) : amount;
    final bg = result.bg;
    return result.copyWith(bg: _lift(_isBare(bg) ? _groundColor : bg!, step));
  }

  /// Moves [color] [amount] of OKLab lightness away from the ground: lighter
  /// on a dark ground, darker on a light one. Under [RenderPolicy.ansi16] a
  /// lift is the bright variant.
  Color _lift(Color color, double amount) {
    if (policy == RenderPolicy.ansi16) return color.lighten(amount);
    final dark = _groundColor.toOklab().l < 0.5;
    return color.shiftLightness(dark ? amount : -amount);
  }

  /// [slot] blended toward the ground when this resolver is de-emphasised
  /// under color; unchanged otherwise.
  Style _quietSlot(Style slot) => isDeEmphasised && policy == RenderPolicy.color ? _blendToGround(slot) : slot;

  /// Applies de-emphasis to a projection: a blend under color, dim elsewhere.
  Style _quiet(Style projection) {
    if (!isDeEmphasised) return projection;
    return policy == RenderPolicy.color ? _blendToGround(projection) : projection.incModifier(Modifier.dim);
  }

  /// Adds dim to a [resolve] result when de-emphasised outside color. Colors
  /// were blended where they were projected.
  Style _dimOutsideColor(Style result) =>
      isDeEmphasised && policy != RenderPolicy.color ? result.incModifier(Modifier.dim) : result;

  /// Moves both halves of [style] toward the ground by [Theme.deEmphasis]. A
  /// half that is null or [Color.reset] stays as it is.
  Style _blendToGround(Style style) {
    Color? blend(Color? color) =>
        color == null || color == Color.reset ? color : color.mix(_groundColor, theme.deEmphasis);
    return style.copyWith(fg: blend(style.fg), bg: blend(style.bg));
  }

  /// Border style for a set of [states], so no call site hand-rolls a
  /// focused-or-resting choice.
  ///
  /// Resolves over the resting border tone as [PaintClass.ink], so a state can
  /// tint the border foreground but never flood a background onto its glyphs.
  /// A focused border is the primary ink plus bold; a selected one is the
  /// primary ink.
  Style border(Set<WidgetState> states) => resolve(ink(tones.border), states, cls: PaintClass.ink);

  /// Projects a tone as foreground-only ink, or drops the color under
  /// [RenderPolicy.noColor] (modifiers added by the caller still ride on top).
  ///
  /// Read [tone] from [tones], not from the theme: the projection itself does
  /// nothing extra under [RenderPolicy.ansi16], so only a tone from the
  /// active set paints as its named-ANSI value. The raw `tone.ink` bypasses
  /// the policy entirely — use these projections for content that must
  /// degrade with the rest of the screen.
  Style ink(Tone tone) => _quiet(policy == RenderPolicy.noColor ? const Style() : tone.ink);

  /// Projects a tone as a filled surface, or degrades it to [Modifier.reversed]
  /// under [RenderPolicy.noColor] so the surface stays distinguishable once its
  /// color is stripped.
  ///
  /// Read [tone] from [tones] — see [ink]. Only a [SurfaceTone] can fill: the
  /// compiler rejects a chrome tone here, since it has no `on` to paint.
  Style fill(SurfaceTone tone) =>
      _quiet(policy == RenderPolicy.noColor ? const Style(addModifier: Modifier.reversed) : tone.fill);

  /// Projects a tone as a background wash, or drops it entirely under
  /// [RenderPolicy.noColor] or [RenderPolicy.ansi16] — a wash cannot exist
  /// without color, and the 16-name vocabulary has no subtle tint to spend on
  /// one either.
  Style wash(Tone tone) =>
      _quiet(policy == RenderPolicy.noColor || policy == RenderPolicy.ansi16 ? const Style() : tone.wash);

  /// Projects a tone as the ground of an area — the style its cells hold
  /// before content paints on them.
  ///
  /// Set this once per area, then paint content on top with a half-null
  /// [Style]; the unset half inherits the ground already in the cell, because
  /// [Cell.setCell] and [Cell.setStyle] patch a cell rather than replace it.
  /// Read [tone] from [tones] — see [ink]. Only a [SurfaceTone] can ground an
  /// area, for the same reason only one can fill.
  ///
  /// In full RGB this is the same style as [fill]. The two projections part
  /// ways only in how they degrade: under [RenderPolicy.ansi16] a ground
  /// keeps only its foreground, leaving the terminal's own background to show
  /// through; under [RenderPolicy.noColor] it carries no color at all.
  Style ground(SurfaceTone tone) => _quiet(switch (policy) {
    RenderPolicy.color => Style(fg: tone.on, bg: tone.color),
    RenderPolicy.ansi16 => Style(fg: tone.on),
    RenderPolicy.noColor => const Style(),
  });
}
