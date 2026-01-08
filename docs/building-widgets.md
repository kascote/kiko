# Building Widgets with Kiko

Guide to using and building stateful widgets in Kiko. Covers MVU integration, event handling, focus management, and common patterns.

## MVU Pattern

### What is MVU?

MVU (Model-View-Update) is an architecture pattern from [Elm](https://guide.elm-lang.org/architecture/) - a functional language for web apps. Also known as "The Elm Architecture" (TEA).

Core idea: **unidirectional data flow** with pure functions.

- **Model** - your entire app state in one place
- **View** - pure function that renders state (no side effects)
- **Update** - pure function that transforms state based on messages

No callbacks. No observers. No mutable state scattered around. State changes only happen in `update`, triggered by messages.

### The Flow

```
                   ┌─────────────────────────────────────┐
                   │                                     │
                   ▼                                     │
    ┌─────────┐   Msg   ┌────────┐  Model   ┌──────┐     │
    │ Runtime │────────▶│ update │─────────▶│ view │─────┘
    └─────────┘         └────────┘          └──────┘
         ▲                  │
         │              Cmd (optional)
         │                  │
         │                  ▼
    ┌─────────┐        ┌─────────┐
    │ Terminal│        │ Effects │
    │ Events  │        │(quit,   │
    └─────────┘        │ async,  │
                       │ timers) │
                       └─────────┘
```

1. Runtime receives events (keys, mouse, timers)
2. Events become `Msg` objects sent to `update`
3. `update` returns new model + optional `Cmd`
4. `view` renders the model to the terminal
5. Commands trigger side effects, which may produce new messages
6. Loop continues

### Why MVU?

- **Predictable** - state only changes via messages, easy to trace
- **Testable** - update/view are pure functions, no mocks needed
- **Debuggable** - log messages to see exactly what happened
- **Composable** - widgets follow same pattern, nest naturally

Trade-off: more boilerplate than imperative style. Worth it for complex UIs.

See: [Elm Guide - Architecture](https://guide.elm-lang.org/architecture/)

### Kiko's Implementation

```dart
await Application(title: 'My App').run(
  init: MyModel(),           // initial state
  update: myUpdate,          // (Model, Msg) -> (Model, Cmd?)
  view: myView,              // (Model, Frame) -> void
);
```

The runtime sends messages (`Msg`) to your `update` function. You return the new model and optionally a command (`Cmd`). The `view` renders the current state.

**Key message types:**

- `KeyMsg` - keyboard input
- `MouseMsg` - mouse events
- `TickMsg` - timer ticks
- `InitMsg` - app startup

**Key commands:**

- `Quit()` - exit the app
- `Emit(msg)` - queue a message
- `Tick(duration)` - start periodic ticks
- `Task(...)` - run async work
- `Unhandled()` - signal parent to handle

## Using Stateful Widgets

Stateful widgets in Kiko have two parts:

1. **Model** - holds state, config, and update logic
2. **Widget** - stateless renderer that reads from the model

### Basic Pattern

```dart
// Create model in your app model
class AppModel {
  final input = TextInputModel(placeholder: 'Enter name');
}

// Route messages to widget in update
(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  final cmd = model.input.update(msg);
  return (model, cmd);
}

// Render in view
void appView(AppModel model, Frame frame) {
  frame.renderWidget(TextInput(model.input), frame.area);
}
```

The widget model's `update()` returns:

- `null` - message handled, no command needed
- `Cmd` - message handled, execute this command
- `Unhandled()` - didn't handle, let parent deal with it

### TextInput Example

See `packages/kiko_widgets/example/text_input.dart` for the full example.

```dart
class AppModel {
  final username = TextInputModel(
    placeholder: 'Enter username',
    maxLength: 20,
    inputFilter: (c) => Characters(c.where((g) => g.trim().isNotEmpty).join()),
  );
  final password = TextInputModel(
    placeholder: 'Enter password',
    obscureText: true,
  );
}
```

Config options:

- `placeholder` - text shown when empty
- `maxLength` - limit character count
- `obscureText` / `obscureChar` - password masking
- `fillChar` / `fillStyle` - fill remaining width
- `inputFilter` - transform/filter input
- `keyBinding` - override default keybindings

### TextArea Example

See `packages/kiko_widgets/example/text_area.dart` for the full example.

```dart
final editor = TextAreaModel(
  placeholder: 'Start typing...',
  showLineNumbers: true,
  maxLines: 100,
);
```

Config options:

- `showLineNumbers` - line number gutter
- `tabWidth` - tab size (default 4)
- `selectionStyle` - highlight color
- `maxLines` - limit line count

## Event Routing

### The Unhandled Pattern

Widgets return `Unhandled()` for keys they don't process. This enables composition:

```
┌─────────────────────────────────────────────────────┐
│ App                                                 │
│                                                     │
│   KeyMsg('a') ─────► widget.update(msg)             │
│                            │                        │
│                            ▼                        │
│                      ┌───────────┐                  │
│                      │ handled?  │                  │
│                      └─────┬─────┘                  │
│                       yes/ \no                      │
│                         /   \                       │
│                        ▼     ▼                      │
│                    return   return                  │
│                    Cmd?     Unhandled()             │
│                      │           │                  │
│                      │           ▼                  │
│                      │     App handles              │
│                      │     (quit, save, etc)        │
│                      │           │                  │
│                      └─────┬─────┘                  │
│                            ▼                        │
│                      return (model, cmd)            │
└─────────────────────────────────────────────────────┘
```

**What widgets handle:** characters, arrows, backspace, delete, home/end
**What bubbles up:** tab (focus), escape (quit), ctrl+s (save), unknown keys

```dart
(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Route to widget first
  final cmd = model.input.update(msg);

  // Widget handled it
  if (cmd is! Unhandled) return (model, cmd);

  // Widget didn't handle - check our shortcuts
  if (msg case KeyMsg(:final key)) {
    if (key == 'ctrl+q') return (model, const Quit());
  }

  return (model, null);
}
```

This is the key composition mechanism in Kiko. Widgets don't need to know about app-level shortcuts, and apps don't need to filter keys before passing to widgets.

## Focus Management

When you have multiple interactive widgets, only one should receive input at a time.

### Manual Focus

The simplest approach - track focus yourself with a list and index:

```dart
class AppModel {
  final name = TextInputModel(placeholder: 'Name');
  final email = TextInputModel(placeholder: 'Email');
  final phone = TextInputModel(placeholder: 'Phone');

  int focusIndex = 0;

  List<TextInputModel> get fields => [name, email, phone];
  TextInputModel get focused => fields[focusIndex];

  void cycleFocus(int delta) {
    // Update all focused states
    for (var i = 0; i < fields.length; i++) {
      fields[i].focused = false;
    }
    focusIndex = (focusIndex + delta) % fields.length;
    if (focusIndex < 0) focusIndex += fields.length;
    fields[focusIndex].focused = true;
  }
}

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Route to focused widget
  final cmd = model.focused.update(msg);
  if (cmd is! Unhandled) return (model, cmd);

  // Handle Tab / Shift+Tab
  if (msg case KeyMsg(key: 'tab')) {
    model.cycleFocus(1);
    return (model, null);
  }
  if (msg case KeyMsg(key: 'shift+tab')) {
    model.cycleFocus(-1);
    return (model, null);
  }

  return (model, null);
}
```

Widget models have a `focused` property. When `false`, their `update()` returns immediately without processing.

See `manual_focus.dart` for the full example.

### FocusGroup Helper

`FocusGroup` automates focus tracking for models that implement `Focusable`:

```dart
class AppModel {
  late final focus = FocusGroup<Focusable>([
    TextInputModel(placeholder: 'Username'),
    TextInputModel(placeholder: 'Password'),
  ]);

  // Typed accessors
  TextInputModel get username => focus.children[0] as TextInputModel;
  TextInputModel get password => focus.children[1] as TextInputModel;
}
```

FocusGroup handles the bookkeeping:

```dart
(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Route to focused widget - cast if needed
  final cmd = (model.focus.focused as TextInputModel).update(msg);
  if (cmd is! Unhandled) return (model, cmd);

  if (msg case KeyMsg(:final key)) {
    if (key == 'tab') {
      model.focus.cycle(1);   // next widget
      return (model, null);
    }
    if (key == 'shift+tab') {
      model.focus.cycle(-1);  // previous widget
      return (model, null);
    }
  }

  return (model, null);
}
```

**FocusGroup API:**

- `children` - the list of focusable items
- `index` - current focus index
- `focused` - currently focused item
- `cycle(delta)` - move focus (+1 forward, -1 back, wraps)
- `setIndex(n)` - jump to specific index

FocusGroup automatically updates each child's `focused` property when cycling.

### Mixed Widget Types

When your focus group has different widget types:

```dart
class AppModel {
  late final focus = FocusGroup<Focusable>([
    TextInputModel(placeholder: 'Title'),
    TextInputModel(placeholder: 'Author'),
    TextAreaModel(placeholder: 'Content...'),
  ]);

  TextInputModel get title => focus.children[0] as TextInputModel;
  TextInputModel get author => focus.children[1] as TextInputModel;
  TextAreaModel get editor => focus.children[2] as TextAreaModel;

  // Route based on type
  Cmd? updateFocused(Msg msg) => switch (focus.index) {
    0 => title.update(msg),
    1 => author.update(msg),
    2 => editor.update(msg),
    _ => null,
  };
}
```

See `packages/kiko_widgets/example/text_area.dart` for a complete mixed-type form.

### Area-Based Focus

Sometimes you need focus between different UI areas, not just Focusable widgets. Use an enum:

```dart
enum FocusArea { search, list }

class AppModel {
  final search = TextInputModel(placeholder: 'Type to filter...');

  FocusArea focusArea = FocusArea.search;
  int listIndex = 0;

  AppModel() {
    search.focused = true;  // initialize
  }

  void setFocus(FocusArea area) {
    focusArea = area;
    search.focused = area == FocusArea.search;
  }
}

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Route to search if focused
  if (model.focusArea == FocusArea.search) {
    final cmd = model.search.update(msg);
    if (cmd is! Unhandled) return (model, cmd);
  }

  if (msg case KeyMsg(:final key)) {
    // Switch areas
    if (key == 'tab') {
      model.setFocus(
        model.focusArea == FocusArea.search ? FocusArea.list : FocusArea.search,
      );
      return (model, null);
    }

    // Arrow keys navigate list (in either area)
    if (key == 'down') {
      if (model.focusArea == FocusArea.search) {
        model.setFocus(FocusArea.list);
      } else {
        model.listIndex++;
      }
      return (model, null);
    }
  }

  return (model, null);
}
```

This pattern is useful when:

- Mixing widget-based and custom focus (search box + list)
- Different areas have different key handling
- Arrow keys should work across focus boundaries

See `searchable_list.dart` for the full example.

## Visual Focus Feedback

Show users which widget is focused by styling borders or backgrounds:

```dart
void appView(AppModel model, Frame frame) {
  final usernameBox = Block(
    borders: Borders.all,
    borderStyle: model.username.focused
      ? const Style(fg: Color.green)      // focused
      : const Style(fg: Color.darkGray),  // unfocused
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: TextInput(model.username),
  ).titleTop(Line('Username'));

  // ... render
}
```

Common patterns:

- Green/highlighted border when focused
- Gray/dim border when not
- Title color change
- Background color change

## Cursor Positioning

Focused widgets position the terminal cursor for text editing:

```dart
// Inside a widget's render()
if (model.focused) {
  frame.cursorPosition = Position(cursorX, cursorY);
}
```

Only one widget should set this per frame - the focused one. Unfocused widgets leave it alone.

## KeyBinding System

Widgets use `KeyBinding<Action>` to map keys to actions:

```dart
enum MyAction { save, cancel, help }

final bindings = KeyBinding<MyAction>()
  ..map(['ctrl+s'], MyAction.save)
  ..map(['escape', 'ctrl+c'], MyAction.cancel)
  ..map(['?', 'f1'], MyAction.help);

// In update
if (msg case KeyMsg()) {
  final action = bindings.resolve(msg);
  if (action != null) {
    // handle action
  }
}
```

Built-in widgets have default bindings you can override:

```dart
final input = TextInputModel(
  keyBinding: defaultTextInputBindings.copy()
    ..map(['ctrl+h'], TextInputAction.backspace),  // add custom
);
```

## Validation Patterns

Use sealed classes for type-safe validation results:

```dart
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
```

Validate in the model, render feedback in view:

```dart
class AppModel {
  final email = TextInputModel(placeholder: 'Email');

  ValidationResult get emailValid {
    final value = email.value;
    if (value.isEmpty) return const Empty();
    if (!value.contains('@')) return const Invalid('Must contain @');
    return const Valid();
  }

  bool get isFormValid => emailValid is Valid;
}
```

Pattern match in view for visual feedback:

```dart
final (borderColor, statusText) = switch (model.emailValid) {
  Valid() => (Color.green, '✓'),
  Invalid(:final message) => (Color.red, message),
  Empty() => (Color.darkGray, 'Required'),
};
```

Combine with input filters for real-time format constraints:

```dart
TextInputModel(
  placeholder: 'Username',
  maxLength: 20,
  inputFilter: (c) => Characters(
    c.where((g) => RegExp(r'^[a-zA-Z0-9_]$').hasMatch(g)).join(),
  ),
)
```

See `validated_form.dart` for the full example.

## Building Custom Widgets

### Stateless Widget

Extend `Widget` and implement `render()`:

```dart
class ListView extends Widget {
  final List<String> items;
  final int selectedIndex;

  ListView({required this.items, required this.selectedIndex});

  @override
  void render(Rect area, Frame frame) {
    if (area.isEmpty) return;

    for (var i = 0; i < area.height && i < items.length; i++) {
      final isSelected = i == selectedIndex;
      final style = isSelected
          ? const Style(fg: Color.black, bg: Color.green)
          : const Style();

      final prefix = isSelected ? '▶ ' : '  ';
      final lineArea = Rect.create(
        x: area.x, y: area.y + i,
        width: area.width, height: 1,
      );

      // Fill background for selection
      if (isSelected) {
        frame.buffer.setStyle(lineArea, style);
      }

      Span('$prefix${items[i]}', style: style).render(lineArea, frame);
    }
  }
}
```

### Model + Widget (Stateful)

Split state/logic from rendering:

```dart
// Model: state + update logic
class CounterModel {
  int count = 0;

  Cmd? update(Msg msg) {
    if (msg case KeyMsg(key: 'up')) {
      count++;
      return null;
    }
    if (msg case KeyMsg(key: 'down')) {
      count--;
      return null;
    }
    return const Unhandled();
  }
}

// Widget: stateless renderer
class Counter extends Widget {
  final CounterModel model;

  Counter(this.model);

  @override
  void render(Rect area, Frame frame) {
    Text.raw('Count: ${model.count}', alignment: Alignment.center)
        .render(area, frame);
  }
}
```

### Widget Checklist

When building a custom widget:

- [ ] Check `area.isEmpty` early
- [ ] Use `frame.buffer.setStyle(area, style)` for backgrounds
- [ ] Use `Span`/`Line`/`Text` for text rendering
- [ ] Set `frame.cursorPosition` if focused and needs cursor
- [ ] Return `Unhandled()` for keys you don't handle
- [ ] Keep render logic simple - compute in model if complex

See `searchable_list.dart` for a custom `_ListView` widget example.

## Examples

All in `packages/kiko_widgets/example/`:

| Example                   | Demonstrates                                         |
| ------------------------- | ---------------------------------------------------- |
| `text_input.dart`         | Basic form with FocusGroup, two inputs               |
| `text_area.dart`          | Mixed form (TextInput + TextArea), status bar        |
| `manual_focus.dart`       | Focus without FocusGroup, manual index tracking      |
| `custom_keybindings.dart` | Vim-style bindings, app-level KeyBinding             |
| `validated_form.dart`     | Input filtering, validation feedback, sealed classes |
| `searchable_list.dart`    | TextInput + list filtering, custom list widget       |

Also see `packages/kiko_core/example/counter.dart` for minimal MVU.

## Reference

**Widget source:**

- `packages/kiko_widgets/lib/src/widgets/text_input.dart`
- `packages/kiko_widgets/lib/src/widgets/text_area/`

**Core types:**

- `packages/kiko_core/lib/src/mvu/focus.dart` - FocusGroup, Focusable
- `packages/kiko_core/lib/src/mvu/msg.dart` - message types
- `packages/kiko_core/lib/src/mvu/cmd.dart` - command types
