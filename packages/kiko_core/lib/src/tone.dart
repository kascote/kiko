import 'package:meta/meta.dart';

import 'colors.dart';
import 'style.dart';

/// A color identity: paint it with [ink] or [wash].
///
/// A tone names *which* color family a cell belongs to, not how it lands as
/// paint. It is deliberately not a [Style] and cannot be painted directly —
/// project it first with [ink] or [wash]. [SurfaceTone] adds a readable
/// foreground and can fill or ground an area; a plain [Tone] cannot, so the
/// compiler rejects a fill of chrome that only ever wanted a foreground tint.
///
/// [color] is nullable: a tone may carry no color at all, and a theme built
/// on the terminal's default background leaves [color] `null`.
///
/// The raw [color] stays public for custom derivations; [ink] and [wash] are
/// the blessed path, not a cage.
@immutable
class Tone {
  /// The identity color of this tone (nullable for terminal-default themes).
  final Color? color;

  /// Creates a tone from an identity [color].
  const Tone({this.color});

  /// Foreground-only projection: paints [color] as the fg, leaving bg untouched.
  ///
  /// Use for line glyphs, separators, scrollbars, and accent text — anything
  /// that tints what is drawn without flooding the cells behind it.
  Style get ink => Style(fg: color);

  /// Background-only projection: paints [color] as the bg, leaving fg untouched.
  ///
  /// Use to tint an area *under* existing content (a crosshair row or column),
  /// so each cell keeps whatever foreground it was already painted with.
  Style get wash => Style(bg: color);

  /// Returns a copy of this tone with [color] replaced.
  Tone copyWith({Color? color}) => Tone(color: color ?? this.color);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType && other is Tone && other.color == color;
  }

  @override
  int get hashCode => Object.hash(Tone, color);

  @override
  String toString() => 'Tone(color: $color)';
}

/// A color identity with a required readable foreground: paint it with
/// [ink], [fill], or [wash].
///
/// Adds [on] to [Tone]: the foreground that reads on top of [color]. A
/// surface tone is the only kind that can fill or ground an area — a
/// selected row, a focused face, a popup's backdrop.
@immutable
class SurfaceTone extends Tone {
  /// A color readable on top of [color] (used as the foreground of [fill]).
  final Color on;

  /// Creates a surface tone from an identity [color] and its readable [on].
  const SurfaceTone({required this.on, super.color});

  /// Surface projection: [on] as the fg over [color] as the bg.
  ///
  /// Use for filled surfaces — selected rows, button faces, badges.
  Style get fill => Style(fg: on, bg: color);

  /// Returns a copy of this tone with the given fields replaced.
  @override
  SurfaceTone copyWith({Color? color, Color? on}) => SurfaceTone(color: color ?? this.color, on: on ?? this.on);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType && other is SurfaceTone && other.color == color && other.on == on;
  }

  @override
  int get hashCode => Object.hash(SurfaceTone, color, on);

  @override
  String toString() => 'SurfaceTone(color: $color, on: $on)';
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
  SurfaceTone get primary;

  /// Second-rank actions, less prominent than [primary].
  SurfaceTone get secondary;

  /// Attention-grabbing color for highlights and badges.
  SurfaceTone get accent;

  /// Destructive actions and invalid/error states.
  SurfaceTone get error;

  /// Cautions and warnings.
  SurfaceTone get warning;

  /// Confirmations and success states.
  SurfaceTone get success;

  /// The app base color.
  SurfaceTone get background;

  /// Elevated surfaces — cards, dialogs, panels.
  SurfaceTone get surface;

  /// Resting chrome (borders, separators).
  Tone get border;

  /// Secondary/dimmed text.
  Tone get muted;

  /// Non-interactive elements.
  Tone get disabled;

  /// Keyboard focus indicator ("you are here").
  SurfaceTone get focus;

  /// Chosen items (selected rows, picked options).
  SurfaceTone get selection;

  /// The current row/column tint.
  SurfaceTone get cursor;
}
