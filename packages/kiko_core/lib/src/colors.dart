import 'dart:math';

import 'package:meta/meta.dart';
import 'package:termansi/termansi.dart' as ansi;

/// Color kind
enum ColorKind {
  /// ANSI color (0-15)
  ansi,

  /// Indexed color (0-255)
  indexed,

  /// RGB color
  rgb,
}

/// Color class
@immutable
class Color {
  /// Color value
  final int value;

  /// Kind of Color
  final ColorKind kind;

  const Color._(this.value, {this.kind = ColorKind.ansi});

  /// Resets the foreground or background color
  static const Color reset = Color._(-1);

  /// ANSI Color: Black. Foreground: 30, Background: 40
  static const Color black = Color._(0);

  /// ANSI Color: Red. Foreground: 31, Background: 41
  static const Color red = Color._(1);

  /// ANSI Color: Green. Foreground: 32, Background: 42
  static const Color green = Color._(2);

  /// ANSI Color: Yellow. Foreground: 33, Background: 43
  static const Color yellow = Color._(3);

  /// ANSI Color: Blue. Foreground: 34, Background: 44
  static const Color blue = Color._(4);

  /// ANSI Color: Magenta. Foreground: 35, Background: 45
  static const Color magenta = Color._(5);

  /// ANSI Color: Cyan. Foreground: 36, Background: 46
  static const Color cyan = Color._(6);

  /// ANSI Color: White. Foreground: 37, Background: 47
  ///
  /// Note that this is sometimes called `silver` or `white` but we use `white` for bright white
  static const Color gray = Color._(7);

  /// ANSI Color: Bright Black. Foreground: 90, Background: 100
  ///
  /// Note that this is sometimes called `light black` or `bright black` but we use `dark gray`
  static const Color darkGray = Color._(8);

  /// ANSI Color: Bright Red. Foreground: 91, Background: 101
  static const Color brightRed = Color._(9);

  /// ANSI Color: Bright Green. Foreground: 92, Background: 102
  static const Color brightGreen = Color._(10);

  /// ANSI Color: Bright Yellow. Foreground: 93, Background: 103
  static const Color brightYellow = Color._(11);

  /// ANSI Color: Bright Blue. Foreground: 94, Background: 104
  static const Color brightBlue = Color._(12);

  /// ANSI Color: Bright Magenta. Foreground: 95, Background: 105
  static const Color brightMagenta = Color._(13);

  /// ANSI Color: Bright Cyan. Foreground: 96, Background: 106
  static const Color brightCyan = Color._(14);

  /// ANSI Color: Bright White. Foreground: 97, Background: 107
  /// Sometimes called `bright white` or `light white` in some terminals
  static const Color white = Color._(15);

  /// Creates a color from an ANSI value (0-15)
  const Color.ansi(int value) : this._(value & 0xf);

  /// Creates a color from an indexed value (0-255)
  const Color.indexed(int value) : this._(value & 0xff, kind: ColorKind.indexed);

  /// Creates a const color from an RGB value (0x000000-0xFFFFFF).
  const Color.rgb(int value) : this._(value & 0xFFFFFF, kind: ColorKind.rgb);

  /// Creates a color from an RGB string (e.g. '#FF0000')
  factory Color.fromRGBString(String rgb) {
    final value = rgb.trim().startsWith('#') ? rgb.trim().substring(1) : rgb.trim();
    if (value.length != 6) {
      throw ArgumentError.value(rgb, 'rgb', 'must be 6 characters long');
    }
    return Color.rgb(int.parse(value, radix: 16));
  }

  /// Converts HSV (Hue, Saturation, Value) color values to RGB Color object.
  ///
  /// Parameters:
  /// - [hue]: The hue value in degrees. Will be normalized between 0 and 360.
  /// - [saturation]: The saturation value, clamped between 0.0 and 1.0.
  /// - [value]: The value/brightness, clamped between 0.0 and 1.0.
  ///
  /// Returns a [Color] object representing the RGB color.
  ///
  /// Note: This is specifically for HSV color space, not HSL. The main difference is
  /// that HSV's value parameter determines brightness (0 = black, 1 = full color),
  /// while HSL's lightness parameter determines lightness (0 = black, 0.5 = full color, 1 = white).
  ///
  /// Example:
  /// ```dart
  /// final color = fromHSV(0, 1.0, 1.0); // Creates pure red
  /// final color = fromHSV(0, 0.0, 1.0); // Creates white
  /// final color = fromHSV(0, 0.0, 0.0); // Creates black
  /// ```
  factory Color.fromHSV(double hue, double saturation, double value) {
    // Converts a color component value to an RGB integer value (0-255).
    int toRGB(double value) => (value * 255).round().clamp(0, 255);

    // Normalize and clamp input values
    final h = hue % 360;
    final s = saturation.clamp(0.0, 1.0);
    final v = value.clamp(0.0, 1.0);

    // Optimization: Early return for black (value = 0)
    if (v <= 0.0) return const Color.rgb(0);

    // Optimization: Early return for grayscale (saturation = 0)
    if (s <= 0.0) {
      final gray = toRGB(v);
      return Color.rgb((gray << 16) | (gray << 8) | gray);
    }

    final hSection = h / 60.0;
    final hSectionInt = hSection.toInt();
    final f = hSection - hSectionInt;

    final p = v * (1 - s);
    final q = v * (1 - s * f);
    final t = v * (1 - s * (1 - f));

    return switch (hSectionInt) {
      0 => Color.rgb((toRGB(v) << 16) | (toRGB(t) << 8) | toRGB(p)),
      1 => Color.rgb((toRGB(q) << 16) | (toRGB(v) << 8) | toRGB(p)),
      2 => Color.rgb((toRGB(p) << 16) | (toRGB(v) << 8) | toRGB(t)),
      3 => Color.rgb((toRGB(p) << 16) | (toRGB(q) << 8) | toRGB(v)),
      4 => Color.rgb((toRGB(t) << 16) | (toRGB(p) << 8) | toRGB(v)),
      _ => Color.rgb((toRGB(v) << 16) | (toRGB(p) << 8) | toRGB(q)),
    };
  }

  @override
  String toString() {
    if (value < 0) return 'Color(Reset)';
    return 'Color($value, ${kind.name})';
  }

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Color) {
      return value == other.value && kind == other.kind;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(Color, value, kind);
  // coverage:ignore-end

  /// Converts this color to RGB.
  ///
  /// - RGB: returns self
  /// - ANSI (0-15): looks up RGB value from ansiHex table
  /// - Indexed (0-255): looks up RGB value from ansiHex table
  /// - Reset: returns [defaultRgb] (defaults to #c0c0c0 for foreground)
  Color toRgb([int defaultRgb = 0xc0c0c0]) {
    return switch (kind) {
      ColorKind.rgb => this,
      ColorKind.ansi =>
        value < 0
            ? Color.rgb(defaultRgb) // reset → default
            : Color.rgb(ansi.ansiHex[value]),
      ColorKind.indexed => Color.rgb(ansi.ansiHex[value]),
    };
  }

  /// Returns a dimmed version of this color as RGB.
  ///
  /// [factor] should be between 0.0 (black) and 1.0 (original color).
  /// [isBackground] when true, treats reset as black instead of gray.
  /// Converts to RGB first, then multiplies each channel by factor.
  Color dim({double factor = 0.3, bool isBackground = false}) {
    final defaultRgb = isBackground ? 0x000000 : 0xc0c0c0;
    final rgb = toRgb(defaultRgb);
    final r = ((rgb.value >> 16) & 0xFF) * factor;
    final g = ((rgb.value >> 8) & 0xFF) * factor;
    final b = (rgb.value & 0xFF) * factor;

    return Color.rgb((r.round() << 16) | (g.round() << 8) | b.round());
  }

  /// Returns the bright variant of an ANSI-16 color.
  ///
  /// A dark ANSI color maps to its bright twin and a bright one stays as it
  /// is. Any other color comes back unchanged, so a lift under the ANSI-16
  /// tier never invents an RGB value.
  ///
  /// [amount] is accepted so a lift reads the same under every tier; it does
  /// not change the result.
  Color lighten(double amount) {
    if (kind == ColorKind.ansi && value >= 0 && value <= 15) {
      return Color._(_ansiBrighten[value]);
    }
    return this;
  }

  /// Perceived brightness of this color, in the range 0.0 (black) to 1.0 (white).
  ///
  /// ANSI and indexed colors are resolved to RGB first, then weighted by how
  /// the eye responds to each channel (green counts most, blue least).
  ///
  /// This is a perceptual weight, not a contrast measure. Use
  /// [relativeLuminance] for contrast.
  double get luminance {
    final rgb = toRgb();
    final r = (rgb.value >> 16) & 0xFF;
    final g = (rgb.value >> 8) & 0xFF;
    final b = rgb.value & 0xFF;
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
  }

  /// WCAG 2 relative luminance of this color, for measuring contrast.
  ///
  /// Call [contrastRatio] to compare two colors. Read this directly only to
  /// feed a contrast formula of your own.
  ///
  /// ANSI and indexed colors resolve to RGB first. Each sRGB channel divides
  /// by 255, then linearizes: by 12.92 at or below 0.03928, else through the
  /// sRGB power curve. The channels weigh 0.2126, 0.7152, 0.0722.
  double get relativeLuminance {
    final rgb = toRgb();
    double linearize(int channel) {
      final c = channel / 255.0;
      return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linearize((rgb.value >> 16) & 0xFF);
    final g = linearize((rgb.value >> 8) & 0xFF);
    final b = linearize(rgb.value & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Contrast ratio between this color and [other], from 1 (no contrast) to 21 (black on white).
  ///
  /// Divides the lighter [relativeLuminance] by the darker, each offset by
  /// 0.05. The result is the same whichever color calls it.
  ///
  /// Grade a text pair against 4.5:1 or 3:1. A separation such as a border
  /// or a cursor bar has no fixed floor; compare the ratio on its own.
  double contrastRatio(Color other) {
    final a = relativeLuminance;
    final b = other.relativeLuminance;
    final lighter = a > b ? a : b;
    final darker = a > b ? b : a;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// This color in OKLab, the perceptual space [shiftLightness] works in.
  ///
  /// ANSI and indexed colors resolve to RGB first, through [toRgb]. The reset
  /// color has no value of its own and converts as the default gray
  /// `0xc0c0c0`.
  Oklab toOklab() {
    final rgb = toRgb();
    double linear(int channel) {
      final c = channel / 255.0;
      return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linear((rgb.value >> 16) & 0xFF);
    final g = linear((rgb.value >> 8) & 0xFF);
    final bl = linear(rgb.value & 0xFF);
    final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl);
    final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl);
    final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl);
    return Oklab(
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    );
  }

  /// Moves this color's OKLab lightness by [delta] and keeps its hue and
  /// chroma.
  ///
  /// A positive [delta] lightens, a negative one darkens. The result is
  /// clamped to lightness 0..1 and, when the moved color falls outside the
  /// sRGB gamut, its chroma is reduced until it fits. The result is RGB, so a
  /// non-RGB color comes back as RGB even when [delta] is zero.
  Color shiftLightness(double delta) {
    final lab = toOklab();
    return Oklab((lab.l + delta).clamp(0.0, 1.0), lab.a, lab.b).toColor();
  }

  /// Blends this color toward [other] by [amount].
  ///
  /// Both colors convert to RGB first, then each channel moves from this
  /// color's value toward [other]'s by [amount] — 0.0 keeps this color, 1.0
  /// becomes [other]. Rounds and clamps each channel; the result is RGB.
  Color mix(Color other, double amount) {
    final from = toRgb();
    final to = other.toRgb();
    final fr = (from.value >> 16) & 0xFF;
    final fg = (from.value >> 8) & 0xFF;
    final fb = from.value & 0xFF;
    final tr = (to.value >> 16) & 0xFF;
    final tg = (to.value >> 8) & 0xFF;
    final tb = to.value & 0xFF;
    final r = fr + (tr - fr) * amount;
    final g = fg + (tg - fg) * amount;
    final b = fb + (tb - fb) * amount;
    return Color.rgb(
      (r.round().clamp(0, 255) << 16) | (g.round().clamp(0, 255) << 8) | b.round().clamp(0, 255),
    );
  }
}

/// ANSI-16 lighten lookup: dark → bright variant.
const _ansiBrighten = [
  8, // black → darkGray
  9, // red → brightRed
  10, // green → brightGreen
  11, // yellow → brightYellow
  12, // blue → brightBlue
  13, // magenta → brightMagenta
  14, // cyan → brightCyan
  15, // gray → white
  8, // darkGray stays
  9, // brightRed stays
  10, // brightGreen stays
  11, // brightYellow stays
  12, // brightBlue stays
  13, // brightMagenta stays
  14, // brightCyan stays
  15, // white stays
];

/// A color in OKLab: lightness [l] from 0 (black) to 1 (white), and the two
/// opponent axes [a] (green to red) and [b] (blue to yellow).
///
/// Equal steps in [l] look equal in size, which sRGB steps do not. Get one
/// from [Color.toOklab]; turn one back with [toColor].
@immutable
class Oklab {
  /// Creates an OKLab triple.
  const Oklab(this.l, this.a, this.b);

  /// Perceptual lightness, 0 black to 1 white.
  final double l;

  /// The green (negative) to red (positive) axis.
  final double a;

  /// The blue (negative) to yellow (positive) axis.
  final double b;

  /// Distance from the neutral axis; 0 is a gray.
  double get chroma => sqrt(a * a + b * b);

  /// This triple as an RGB [Color].
  ///
  /// A triple outside the sRGB gamut keeps its lightness and hue and loses
  /// chroma until it fits; the channels are then rounded to 8 bits.
  Color toColor() {
    var scale = 1.0;
    var rgb = _linearRgb(l, a, b);
    if (!_inGamut(rgb)) {
      var lo = 0.0;
      var hi = 1.0;
      for (var i = 0; i < 16; i++) {
        scale = (lo + hi) / 2;
        rgb = _linearRgb(l, a * scale, b * scale);
        if (_inGamut(rgb)) {
          lo = scale;
        } else {
          hi = scale;
        }
      }
      rgb = _linearRgb(l, a * lo, b * lo);
    }
    int channel(double c) {
      final clamped = c.clamp(0.0, 1.0);
      final srgb = clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1 / 2.4) - 0.055;
      return (srgb * 255).round().clamp(0, 255);
    }

    return Color.rgb((channel(rgb.$1) << 16) | (channel(rgb.$2) << 8) | channel(rgb.$3));
  }

  static bool _inGamut((double, double, double) rgb) {
    const slack = 0.0005;
    bool ok(double c) => c >= -slack && c <= 1 + slack;
    return ok(rgb.$1) && ok(rgb.$2) && ok(rgb.$3);
  }

  static (double, double, double) _linearRgb(double l, double a, double b) {
    final l1 = l + 0.3963377774 * a + 0.2158037573 * b;
    final m1 = l - 0.1055613458 * a - 0.0638541728 * b;
    final s1 = l - 0.0894841775 * a - 1.2914855480 * b;
    final l3 = l1 * l1 * l1;
    final m3 = m1 * m1 * m1;
    final s3 = s1 * s1 * s1;
    return (
      4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
      -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
      -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
    );
  }

  @override
  bool operator ==(Object other) => other is Oklab && other.l == l && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(Oklab, l, a, b);

  @override
  String toString() => 'Oklab(l: ${l.toStringAsFixed(3)}, a: ${a.toStringAsFixed(3)}, b: ${b.toStringAsFixed(3)})';
}

double _cbrt(double x) => x < 0 ? -pow(-x, 1 / 3).toDouble() : pow(x, 1 / 3).toDouble();
