// Demonstrates form validation patterns.
//
// Shows how to:
// - Use input filters for format constraints
// - Display real-time validation errors
// - Show submit status based on validity

import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// VALIDATION
// ═══════════════════════════════════════════════════════════

/// Validation result for a field.
sealed class ValidationResult {
  const ValidationResult();
}

class Valid extends ValidationResult {
  const Valid();
}

class Invalid extends ValidationResult {
  final String message;
  const Invalid(this.message);
}

class Empty extends ValidationResult {
  const Empty();
}

/// Validates username: 3-20 chars, alphanumeric + underscore.
ValidationResult validateUsername(String value) {
  if (value.isEmpty) return const Empty();
  if (value.length < 3) return const Invalid('Min 3 characters');
  if (value.length > 20) return const Invalid('Max 20 characters');
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
    return const Invalid('Only letters, numbers, underscore');
  }
  return const Valid();
}

/// Validates email: basic format check.
ValidationResult validateEmail(String value) {
  if (value.isEmpty) return const Empty();
  if (!value.contains('@')) return const Invalid('Must contain @');
  if (!value.contains('.')) return const Invalid('Must contain domain');
  final parts = value.split('@');
  if (parts.length != 2) return const Invalid('Invalid format');
  if (parts[0].isEmpty) return const Invalid('Missing local part');
  if (parts[1].isEmpty) return const Invalid('Missing domain');
  return const Valid();
}

/// Validates password: min 8 chars, mixed case + number.
ValidationResult validatePassword(String value) {
  if (value.isEmpty) return const Empty();
  if (value.length < 8) return const Invalid('Min 8 characters');
  if (!RegExp('[a-z]').hasMatch(value)) return const Invalid('Need lowercase');
  if (!RegExp('[A-Z]').hasMatch(value)) return const Invalid('Need uppercase');
  if (!RegExp('[0-9]').hasMatch(value)) return const Invalid('Need number');
  return const Valid();
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  late final focus = FocusGroup<Focusable>([
    TextInputModel(
      placeholder: 'Username',
      maxLength: 20,
      // Only allow valid username chars
      inputFilter: (c) => Characters(
        c.where((g) => RegExp(r'^[a-zA-Z0-9_]$').hasMatch(g)).join(),
      ),
    ),
    TextInputModel(placeholder: 'Email'),
    TextInputModel(
      placeholder: 'Password',
      obscureText: true,
      maxLength: 50,
    ),
  ]);

  String? submitMessage;
  bool submitted = false;

  TextInputModel get username => focus.children[0] as TextInputModel;
  TextInputModel get email => focus.children[1] as TextInputModel;
  TextInputModel get password => focus.children[2] as TextInputModel;

  ValidationResult get usernameValid => validateUsername(username.value);
  ValidationResult get emailValid => validateEmail(email.value);
  ValidationResult get passwordValid => validatePassword(password.value);

  bool get isFormValid => usernameValid is Valid && emailValid is Valid && passwordValid is Valid;

  int get validCount => [usernameValid, emailValid, passwordValid].whereType<Valid>().length;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Clear submit message on any input
  if (msg is KeyMsg && model.submitMessage != null) {
    model.submitMessage = null;
  }

  // Route to focused widget
  final focused = model.focus.focused as TextInputModel;
  final cmd = focused.update(msg);
  if (cmd is! Unhandled) return (model, cmd);

  if (msg case KeyMsg(:final key)) {
    // Tab cycling
    if (key == 'tab') {
      model.focus.cycle(1);
      return (model, null);
    }
    if (key == 'shift+tab') {
      model.focus.cycle(-1);
      return (model, null);
    }

    // Submit
    if (key == 'enter' || key == 'ctrl+s') {
      if (model.isFormValid) {
        model
          ..submitMessage = 'Form submitted successfully!'
          ..submitted = true;
      } else {
        model.submitMessage = 'Please fix validation errors (${model.validCount}/3 valid)';
      }
      return (model, null);
    }

    // Quit
    if (key == 'escape' || key == 'ctrl+q') {
      return (model, const Quit());
    }
  }

  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void appView(AppModel model, Frame frame) {
  final theme = model.theme;
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final ui = box(
    border: BorderType.plain,
    borderStyle: theme.border,
    topTitles: [Line('Validated Form Demo', style: theme.muted)],
    child: plume.Column<PaintToken>(
      crossAxisAlignment: plume.CrossAxisAlignment.stretch,
      children: [
        _fieldWithValidation(model.username, 'Username', model.usernameValid, theme),
        _fieldWithValidation(model.email, 'Email', model.emailValid, theme),
        _fieldWithValidation(model.password, 'Password', model.passwordValid, theme),
        // Submit status
        plume.Padding<PaintToken>(
          insets: const plume.EdgeInsets.only(top: 1),
          child: lineNode(
            Line(
              model.submitMessage ?? (model.isFormValid ? 'Press Enter to submit' : 'Fill all fields correctly'),
              style: Style(
                fg: model.submitted
                    ? theme.success.fg
                    : model.submitMessage != null
                    ? theme.error.fg
                    : theme.muted.fg,
              ),
              alignment: Alignment.center,
            ),
          ),
        ),
        // Spacer
        plume.Expanded<PaintToken>(child: plume.SizedBox<PaintToken>()),
        // Help
        plume.Row<PaintToken>(
          children: [
            plume.Expanded<PaintToken>(
              child: lineNode(Line('Tab to cycle | Enter submit | Esc quit', style: theme.muted)),
            ),
            plume.ConstrainedBox<PaintToken>(
              additionalConstraints: const plume.BoxConstraints(minW: 25, maxW: 25),
              child: lineNode(
                Line('Theme: ${model.themeName} (F1/F2)', style: theme.muted, alignment: Alignment.right),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  frame.renderNode(ui);
}

/// A bordered, titled field with a fixed-height [textInput] and a validation
/// status column to its right.
plume.RenderNode<PaintToken> _fieldWithValidation(
  TextInputModel input,
  String label,
  ValidationResult validation,
  Theme theme,
) {
  final (borderStyle, statusText, statusColor) = switch (validation) {
    Valid() => (theme.success, '✓', theme.success.fg),
    Invalid(:final message) => (theme.error, message, theme.error.fg),
    Empty() => (theme.border, 'Required', theme.muted.fg),
  };

  final effectiveBorder = input.focused ? theme.focus : borderStyle;

  return plume.Row<PaintToken>(
    children: [
      plume.Expanded<PaintToken>(
        child: box(
          border: BorderType.plain,
          borderStyle: effectiveBorder,
          padding: const plume.EdgeInsets.symmetric(horizontal: 1),
          topTitles: [Line(label)],
          child: plume.ConstrainedBox<PaintToken>(
            additionalConstraints: const plume.BoxConstraints(minH: 1, maxH: 1),
            child: textInput(input, theme),
          ),
        ),
      ),
      plume.ConstrainedBox<PaintToken>(
        additionalConstraints: const plume.BoxConstraints(minW: 25, maxW: 25),
        child: plume.Padding<PaintToken>(
          insets: const plume.EdgeInsets.only(left: 1, top: 1),
          child: lineNode(Line(statusText, style: Style(fg: statusColor))),
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Validated Form Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
