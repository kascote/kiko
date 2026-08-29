// Demonstrates form validation patterns.
//
// Shows how to:
// - Use input filters for format constraints
// - Display real-time validation errors
// - Show submit status based on validity
// - Let FocusRouter own the interaction wiring (Tab cycling, click-to-focus,
//   pointer and keyboard routing) while the app keeps the domain keys:
//   submit on Enter and quit on Escape run only for input every field declined

import 'dart:io';

import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

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
  late final focus = FocusGroup<Component>([
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

  late final router = FocusRouter(focus);

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

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext ctx) {
  // Theme keys are app-owned; intercept them before any widget sees them.
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Domain state next: any keystroke clears a stale submit message on its
  // way through, whether or not the focused field goes on to consume it.
  // Pointer traffic deliberately leaves the message alone.
  if (msg is KeyMsg && model.submitMessage != null) {
    model.submitMessage = null;
  }

  // One router call replaces the hand-rolled glue: Tab/Shift+Tab cycle focus,
  // any other key goes to the focused field, a pointer goes to whichever
  // field it's addressed to, and a down-click moves keyboard focus there.
  switch (model.router.route(msg, ctx)) {
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic — fall through to fallback keys
  }

  // Fallback keys run only for input every widget declined — a field never
  // consumes Enter, so submit lands here; a field consuming keystrokes can
  // never trigger quit.
  if (msg case KeyMsg(:final key)) {
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
  final resolver = StyleResolver(theme);
  final t = resolver.tones;
  frame.buffer.setStyle(frame.area, resolver.ground(resolver.tones.background));

  final ui = Container(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    topTitles: [Line('Validated Form Demo', style: resolver.ink(t.muted))],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        _fieldWithValidation(model.username, 'Username', model.usernameValid, resolver),
        _fieldWithValidation(model.email, 'Email', model.emailValid, resolver),
        _fieldWithValidation(model.password, 'Password', model.passwordValid, resolver),
        // Submit status
        Padding(
          insets: const EdgeInsets.only(top: 1),
          child: Center(
            child: Line(
              model.submitMessage ?? (model.isFormValid ? 'Press Enter to submit' : 'Fill all fields correctly'),
              style: resolver.ink(
                model.submitted
                    ? t.success
                    : model.submitMessage != null
                    ? t.error
                    : t.muted,
              ),
            ),
          ),
        ),
        // Spacer
        const Expanded(child: SizedBox()),
        // Help
        Row(
          children: [
            Expanded(
              child: Line('Tab/click to cycle | Enter submit | Esc quit', style: resolver.ink(t.muted)),
            ),
            ConstrainedBox(
              additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
              child: Align(
                alignment: Alignment.centerRight,
                child: Line('Theme: ${model.themeName} (F1/F2)', style: resolver.ink(t.muted)),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  frame.render(ui);
}

/// A bordered, titled field with a fixed-height [TextInput] and a validation
/// status column to its right.
View _fieldWithValidation(
  TextInputModel input,
  String label,
  ValidationResult validation,
  StyleResolver resolver,
) {
  final t = resolver.tones;
  final (borderTone, statusText, statusTone) = switch (validation) {
    Valid() => (t.success, '✓', t.success),
    Invalid(:final message) => (t.error, message, t.error),
    Empty() => (t.border, 'Required', t.muted),
  };

  final effectiveBorder = resolver.resolve(
    resolver.ink(borderTone),
    {if (input.focused) WidgetState.focused},
    cls: PaintClass.ink,
  );

  return Row(
    children: [
      Expanded(
        child: Container(
          border: BorderType.plain,
          borderStyle: effectiveBorder,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          topTitles: [Line(label)],
          child: ConstrainedBox(
            additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
            child: TextInput(model: input, theme: resolver.theme),
          ),
        ),
      ),
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
        child: Padding(
          insets: const EdgeInsets.only(left: 1, top: 1),
          child: Line(statusText, style: resolver.ink(statusTone)),
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Validated Form Demo', mouseEvents: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
