// Demonstrates form validation patterns.
//
// Shows how to:
// - Use input filters for format constraints
// - Display real-time validation errors
// - Show submit status based on validity

import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

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

class AppModel {
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
  LayoutChild fieldWithValidation(
    TextInputModel input,
    String label,
    ValidationResult validation,
  ) {
    final (borderColor, statusText, statusColor) = switch (validation) {
      Valid() => (Color.green, '✓', Color.green),
      Invalid(:final message) => (Color.red, message, Color.red),
      Empty() => (Color.darkGray, 'Required', Color.darkGray),
    };

    final dimColor = input.focused ? borderColor : Color.darkGray;

    return Fixed(
      3,
      child: Row(
        children: [
          Expanded(
            child: Block(
              borders: Borders.all,
              borderStyle: Style(fg: dimColor),
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: TextInput(input),
            ).titleTop(Line(label)),
          ),
          Fixed(
            25,
            child: Padding(
              padding: const EdgeInsets(left: 1, top: 1),
              child: Text.raw(statusText, style: Style(fg: statusColor)),
            ),
          ),
        ],
      ),
    );
  }

  final ui =
      Block(
        child: Column(
          children: [
            fieldWithValidation(model.username, 'Username', model.usernameValid),
            fieldWithValidation(model.email, 'Email', model.emailValid),
            fieldWithValidation(model.password, 'Password', model.passwordValid),
            // Submit status
            Fixed(
              2,
              child: Padding(
                padding: const EdgeInsets(top: 1),
                child: Text.raw(
                  model.submitMessage ?? (model.isFormValid ? 'Press Enter to submit' : 'Fill all fields correctly'),
                  style: Style(
                    fg: model.submitted
                        ? Color.green
                        : model.submitMessage != null
                        ? Color.red
                        : Color.darkGray,
                  ),
                  alignment: Alignment.center,
                ),
              ),
            ),
            // Spacer
            Expanded(child: const Block()),
            // Help
            Fixed(
              1,
              child: Text.raw(
                'Tab to cycle | Enter to submit | Esc to quit',
                alignment: Alignment.center,
                style: const Style(fg: Color.darkGray),
              ),
            ),
          ],
        ),
      ).titleTop(
        Line('Validated Form Demo', style: const Style(fg: Color.darkGray)),
      );

  frame.renderWidget(ui, frame.area);
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
