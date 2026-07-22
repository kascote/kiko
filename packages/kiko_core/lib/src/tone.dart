import 'package:meta/meta.dart';

import 'colors.dart';
import 'style.dart';

/// A color identity: a [color] and a color [on] that reads on top of it.
///
/// A tone names *which* color family a cell belongs to, not how it lands as
/// paint. It is deliberately not a [Style] and cannot be painted directly —
/// project it first with [ink], [fill], or [wash]. That extra step is what
/// keeps a fill's background from bleeding onto chrome that only wanted a
/// foreground tint.
///
/// Both halves are nullable: a tone may carry only a [color] (chrome, text
/// tints), and a theme built on the terminal's default background leaves
/// [color] `null` so fills fall back to that default.
///
/// The raw [color] and [on] stay public for custom derivations; the three
/// projections are the blessed path, not a cage.
@immutable
class Tone {
  /// The identity color of this tone (nullable for terminal-default themes).
  final Color? color;

  /// A color readable on top of [color] (used as the foreground of [fill]).
  final Color? on;

  /// Creates a tone from an identity [color] and an optional [on] color.
  const Tone({this.color, this.on});

  /// Foreground-only projection: paints [color] as the fg, leaving bg untouched.
  ///
  /// Use for line glyphs, separators, scrollbars, and accent text — anything
  /// that tints what is drawn without flooding the cells behind it.
  Style get ink => Style(fg: color);

  /// Surface projection: [on] as the fg over [color] as the bg.
  ///
  /// Use for filled surfaces — selected rows, button faces, badges.
  Style get fill => Style(fg: on, bg: color);

  /// Background-only projection: paints [color] as the bg, leaving fg untouched.
  ///
  /// Use to tint an area *under* existing content (a crosshair row or column),
  /// so each cell keeps whatever foreground it was already painted with.
  Style get wash => Style(bg: color);

  /// Returns a copy of this tone with the given fields replaced.
  Tone copyWith({Color? color, Color? on}) => Tone(color: color ?? this.color, on: on ?? this.on);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tone && other.color == color && other.on == on;
  }

  @override
  int get hashCode => Object.hash(Tone, color, on);

  @override
  String toString() => 'Tone(color: $color, on: $on)';
}

/// A uniform view over a theme's core tones, independent of whether the
/// colors underneath are full RGB or a fixed ANSI-16 palette.
///
/// `Theme` implements this directly (its native RGB tones); `Ansi16Tones`
/// implements it too (the named-ANSI re-expression used under
/// `RenderPolicy.ansi16`). `StyleResolver` resolves exactly one active tone
/// set per instance and reads every state through this shape, so its state
/// matrix never branches per call site on which kind of tone it is holding.
///
/// `hover` is deliberately not part of this set: it only ever paints as a
/// [Tone.wash], and washes drop entirely at the ANSI-16 tier, so there is
/// nothing for an ANSI-16 table to carry for it.
abstract class ToneSet {
  /// Main brand color for primary actions.
  Tone get primary;

  /// Second-rank actions, less prominent than [primary].
  Tone get secondary;

  /// Attention-grabbing color for highlights and badges.
  Tone get accent;

  /// Destructive actions and invalid/error states.
  Tone get error;

  /// Cautions and warnings.
  Tone get warning;

  /// Confirmations and success states.
  Tone get success;

  /// The app base color.
  Tone get background;

  /// Elevated surfaces — cards, dialogs, panels.
  Tone get surface;

  /// Resting chrome (borders, separators).
  Tone get border;

  /// Secondary/dimmed text.
  Tone get muted;

  /// Non-interactive elements.
  Tone get disabled;

  /// Keyboard focus indicator ("you are here").
  Tone get focus;

  /// Chosen items (selected rows, picked options).
  Tone get selection;

  /// The current row/column tint.
  Tone get cursor;
}
