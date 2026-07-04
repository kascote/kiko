import 'package:kiko/kiko.dart';

/// Mixin for models that want theme switching capability.
///
/// Usage:
/// ```dart
/// class AppModel with ThemeSwitcher {
///   // model fields...
/// }
///
/// // In update:
/// if (model.handleThemeSwitch(msg)) return (model, null);
///
/// // In view:
/// final theme = model.theme;
/// // Use model.themeName for display
/// ```
mixin ThemeSwitcher {
  int _themeIndex = 0;

  static const List<Theme> _themes = [
    Theme.dark,
    Theme.light,
    Theme.ember,
    Theme.ansiDark,
  ];

  static const List<String> _themeNames = [
    'Kiko Dark',
    'Kiko Light',
    'Ember',
    'ANSI-16',
  ];

  Theme get theme => _themes[_themeIndex];
  String get themeName => _themeNames[_themeIndex];

  void nextTheme() => _themeIndex = (_themeIndex + 1) % _themes.length;
  void prevTheme() => _themeIndex = (_themeIndex - 1 + _themes.length) % _themes.length;

  /// Handle theme switching keys. Returns true if handled.
  ///
  /// Keys: F1/F2 to switch themes.
  bool handleThemeSwitch(Msg msg) {
    if (msg case KeyMsg(:final key)) {
      if (key == 'f1') {
        prevTheme();
        return true;
      }
      if (key == 'f2') {
        nextTheme();
        return true;
      }
    }
    return false;
  }
}
