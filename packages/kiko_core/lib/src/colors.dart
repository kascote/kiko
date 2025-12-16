import 'package:meta/meta.dart';

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
  factory Color.ansi(int value) {
    if (value < 0 || value > 15) {
      throw ArgumentError.value(value, 'value', 'must be between 0 and 15');
    }
    return Color._(value & 0xf);
  }

  /// Creates a color from an indexed value (0-255)
  factory Color.indexed(int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError.value(value, 'value', 'must be between 0 and 255');
    }
    return Color._(value & 0xff, kind: ColorKind.indexed);
  }

  /// Creates a color from an RGB value (0x000000-0xFFFFFF)
  factory Color.fromRGB(int rgb) {
    return Color._(rgb & 0xFFFFFF, kind: ColorKind.rgb);
  }

  /// Creates a color from an RGB string (e.g. '#FF0000')
  factory Color.fromRGBString(String rgb) {
    final value = rgb.startsWith('#') ? rgb.substring(1) : rgb;
    if (value.length != 6) {
      throw ArgumentError.value(rgb, 'rgb', 'must be 6 characters long');
    }
    return Color._(int.parse(value, radix: 16), kind: ColorKind.rgb);
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
    if (v <= 0.0) {
      return Color.fromRGB(0);
    }

    // Optimization: Early return for grayscale (saturation = 0)
    if (s <= 0.0) {
      final gray = toRGB(v);
      return Color.fromRGB((gray << 16) | (gray << 8) | gray);
    }

    final hSection = h / 60.0;
    final hSectionInt = hSection.toInt();
    final f = hSection - hSectionInt;

    final p = v * (1 - s);
    final q = v * (1 - s * f);
    final t = v * (1 - s * (1 - f));

    return switch (hSectionInt) {
      0 => Color.fromRGB((toRGB(v) << 16) | (toRGB(t) << 8) | toRGB(p)),
      1 => Color.fromRGB((toRGB(q) << 16) | (toRGB(v) << 8) | toRGB(p)),
      2 => Color.fromRGB((toRGB(p) << 16) | (toRGB(v) << 8) | toRGB(t)),
      3 => Color.fromRGB((toRGB(p) << 16) | (toRGB(q) << 8) | toRGB(v)),
      4 => Color.fromRGB((toRGB(t) << 16) | (toRGB(p) << 8) | toRGB(v)),
      _ => Color.fromRGB((toRGB(v) << 16) | (toRGB(p) << 8) | toRGB(q)),
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
}
