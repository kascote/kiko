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

  /// Returns a lighter version of this color.
  ///
  /// [amount] should be between 0.0 (no change) and 1.0 (white).
  /// RGB/indexed colors are converted to RGB and each channel is lerped
  /// toward 255. ANSI-16 dark colors map to their bright variant.
  Color lighten(double amount) {
    if (kind == ColorKind.ansi && value >= 0 && value <= 15) {
      return Color._(_ansiBrighten[value]);
    }
    final rgb = toRgb();
    final r = ((rgb.value >> 16) & 0xFF) + ((255 - ((rgb.value >> 16) & 0xFF)) * amount);
    final g = ((rgb.value >> 8) & 0xFF) + ((255 - ((rgb.value >> 8) & 0xFF)) * amount);
    final b = (rgb.value & 0xFF) + ((255 - (rgb.value & 0xFF)) * amount);
    return Color.rgb(
      (r.round().clamp(0, 255) << 16) | (g.round().clamp(0, 255) << 8) | b.round().clamp(0, 255),
    );
  }

  /// Returns a darker version of this color.
  ///
  /// [amount] should be between 0.0 (no change) and 1.0 (black).
  /// RGB/indexed colors are converted to RGB and each channel is lerped
  /// toward 0. ANSI-16 bright colors map to their dark variant.
  Color darken(double amount) {
    if (kind == ColorKind.ansi && value >= 0 && value <= 15) {
      return Color._(_ansiDarken[value]);
    }
    final rgb = toRgb();
    final factor = 1.0 - amount;
    final r = ((rgb.value >> 16) & 0xFF) * factor;
    final g = ((rgb.value >> 8) & 0xFF) * factor;
    final b = (rgb.value & 0xFF) * factor;
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

/// ANSI-16 darken lookup: bright → dark variant.
const _ansiDarken = [
  0, // black stays
  1, // red stays
  2, // green stays
  3, // yellow stays
  4, // blue stays
  5, // magenta stays
  6, // cyan stays
  7, // gray stays
  0, // darkGray → black
  1, // brightRed → red
  2, // brightGreen → green
  3, // brightYellow → yellow
  4, // brightBlue → blue
  5, // brightMagenta → magenta
  6, // brightCyan → cyan
  7, // white → gray
];
