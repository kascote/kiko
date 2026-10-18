import 'dart:math';

import 'package:meta/meta.dart';

import 'colors.dart';
import 'theme.dart';
import 'tone.dart';

/// A theme's tones re-expressed as the fixed ANSI-16 palette.
///
/// A plain 16-color terminal has sixteen fixed slots the user has already
/// picked colors for. Each tone takes one named slot by its hue family, so
/// [error] stays red-family and [selection] stays blue-family, and the
/// terminal's own palette still reads correctly.
///
/// Get a table with [Ansi16Tones.derive]. No theme authors one.
///
/// Every entry's [Tone.color] (when set) is an ANSI-kind [Color] in the 0-15
/// range. Nine entries are [SurfaceTone]; each one's [SurfaceTone.on] is
/// black or white, picked from the slot. The three chrome entries (`border`,
/// `muted`, `disabled`) are a plain [Tone] and carry no `on`, same as on the
/// theme they come from.
@immutable
class Ansi16Tones implements ToneSet {
  /// Main brand color for primary actions, as a named ANSI-16 pair.
  @override
  final SurfaceTone primary;

  /// Second-rank actions, less prominent than [primary].
  @override
  final SurfaceTone secondary;

  /// Attention-grabbing color for highlights and badges.
  @override
  final SurfaceTone accent;

  /// Destructive actions and invalid/error states.
  @override
  final SurfaceTone error;

  /// Cautions and warnings.
  @override
  final SurfaceTone warning;

  /// Confirmations and success states.
  @override
  final SurfaceTone success;

  /// The app base color.
  @override
  final SurfaceTone background;

  /// Elevated surfaces — cards, dialogs, panels.
  @override
  final SurfaceTone surface;

  /// Resting chrome (borders, separators).
  @override
  final Tone border;

  /// Secondary/dimmed text.
  @override
  final Tone muted;

  /// Non-interactive elements.
  @override
  final Tone disabled;

  /// Chosen items (selected rows, picked options).
  @override
  final SurfaceTone selection;

  /// Creates a table from its named tones.
  const Ansi16Tones({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.error,
    required this.warning,
    required this.success,
    required this.background,
    required this.surface,
    required this.border,
    required this.muted,
    required this.disabled,
    required this.selection,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ansi16Tones &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.accent == accent &&
        other.error == error &&
        other.warning == warning &&
        other.success == success &&
        other.background == background &&
        other.surface == surface &&
        other.border == border &&
        other.muted == muted &&
        other.disabled == disabled &&
        other.selection == selection;
  }

  @override
  int get hashCode => Object.hash(
    Ansi16Tones,
    primary,
    secondary,
    accent,
    error,
    warning,
    success,
    background,
    surface,
    border,
    muted,
    disabled,
    selection,
  );

  // Derived tables, keyed by value. Theme has value equality, so a theme
  // variant built fresh each frame still hits the entry of any equal theme
  // built before it; built-in themes are consts, so their entries stay
  // stable for the life of the process.
  static final Map<Theme, Ansi16Tones> _memo = {};

  /// The OKLab chroma below which a hued tone counts as gray.
  @visibleForTesting
  static const double grayChroma = 0.02;

  /// The OKLab lightness above which a hued tone takes its bright variant.
  @visibleForTesting
  static const double brightLightness = 0.9;

  /// The OKLab lightness below which a gray is black.
  @visibleForTesting
  static const double blackBelow = 0.22;

  /// The OKLab lightness below which a gray, above black, is dark gray.
  @visibleForTesting
  static const double darkGrayBelow = 0.59;

  /// The OKLab lightness below which a gray, above dark gray, is gray. Above
  /// it, a gray is white.
  @visibleForTesting
  static const double grayBelow = 0.9;

  /// The OKLab hue angle, in degrees, of each hue family's ANSI color.
  ///
  /// Computed from the RGB value of the dark red, yellow, green, cyan, blue
  /// and magenta slots. A tone joins the family whose angle is nearest.
  @visibleForTesting
  static List<(Color, double)> get hueCenters => _families;

  static final List<(Color, double)> _families = [
    for (final slot in [Color.red, Color.yellow, Color.green, Color.cyan, Color.blue, Color.magenta])
      (slot, _hueOf(slot.toOklab())),
  ];

  // Slots whose own color reads dark, so their text is white.
  static const _darkSlots = {0, 1, 4, 8, 9, 12};

  /// Derives an [Ansi16Tones] table from [theme]'s tones.
  ///
  /// Computed once per [theme] and cached, so every resolver built from the
  /// same theme shares one table.
  ///
  /// The intent tones and [selection] pick a hue family. A color whose OKLab
  /// chroma is under [grayChroma] is a gray, except [selection], which takes
  /// blue: a gray selection would match the lifted ground a cursor row paints.
  /// Otherwise the nearest family center by hue angle wins, and a color
  /// lighter than [brightLightness] takes the family's bright variant. The neutral tones (`background`,
  /// `surface`, `border`, `muted`, `disabled`) always take one of the four
  /// grays by lightness, whatever their chroma. An ANSI color passes through
  /// unchanged and an indexed color converts through its RGB value. A tone
  /// with no color keeps none.
  ///
  /// A surface tone's `on` is black or white by the slot it lands on. Black,
  /// red, blue, dark gray and the bright red and blue take white. The rest
  /// take black.
  ///
  /// Tones that land on one slot stay on it; the derivation does not spread
  /// them apart.
  factory Ansi16Tones.derive(Theme theme) {
    final cached = _memo[theme];
    if (cached != null) return cached;

    final derived = Ansi16Tones(
      primary: _surface(theme.primary, _hued),
      secondary: _surface(theme.secondary, _hued),
      accent: _surface(theme.accent, _hued),
      error: _surface(theme.error, _hued),
      warning: _surface(theme.warning, _hued),
      success: _surface(theme.success, _hued),
      background: _surface(theme.background, _neutral),
      surface: _surface(theme.surface, _neutral),
      border: Tone(color: _neutral(theme.border.color)),
      muted: Tone(color: _neutral(theme.muted.color)),
      disabled: Tone(color: _neutral(theme.disabled.color)),
      selection: _surface(theme.selection, (color) => _hued(color, achromatic: Color.blue)),
    );
    _memo[theme] = derived;
    return derived;
  }

  // Derives a surface tone's named pair. A tone with no color has no slot to
  // read `on` from, so its own `on` goes through the same mapping.
  static SurfaceTone _surface(SurfaceTone tone, Color? Function(Color?) slotFor) {
    final color16 = slotFor(tone.color);
    if (color16 == null) return SurfaceTone(on: slotFor(tone.on)!);
    return SurfaceTone(color: color16, on: _onFor(color16));
  }

  // Maps a color of any kind to its hue-family slot. Null stays null and an
  // ANSI color is already a slot.
  // A color under [grayChroma] takes [achromatic], or its gray when there is
  // none.
  static Color? _hued(Color? color, {Color? achromatic}) {
    if (color == null || color.kind == ColorKind.ansi) return color;
    final lab = color.toOklab();
    if (lab.chroma < grayChroma) return achromatic ?? _grayFor(lab.l);
    var family = _families.first;
    var distance = double.infinity;
    for (final candidate in _families) {
      final apart = _hueApart(candidate.$2, _hueOf(lab));
      if (apart < distance) {
        distance = apart;
        family = candidate;
      }
    }
    final slot = family.$1.value;
    return Color.ansi(lab.l > brightLightness ? slot + 8 : slot);
  }

  // Maps a color of any kind to one of the four grays by lightness.
  static Color? _neutral(Color? color) {
    if (color == null || color.kind == ColorKind.ansi) return color;
    return _grayFor(color.toOklab().l);
  }

  static Color _grayFor(double lightness) {
    if (lightness < blackBelow) return Color.black;
    if (lightness < darkGrayBelow) return Color.darkGray;
    if (lightness < grayBelow) return Color.gray;
    return Color.white;
  }

  static double _hueOf(Oklab lab) => (atan2(lab.b, lab.a) * 180 / pi + 360) % 360;

  static double _hueApart(double a, double b) {
    final apart = (a - b).abs();
    return apart > 180 ? 360 - apart : apart;
  }

  static Color _onFor(Color color16) => _darkSlots.contains(color16.value) ? Color.white : Color.black;
}
