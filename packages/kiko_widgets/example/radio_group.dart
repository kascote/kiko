// This example runs every case a radio group covers: the glyph presets, a
// vertical group beside a horizontal one, the label/box layouts lined up in
// one column, a form wired through one FocusRouter, a group with a disabled
// option the arrows skip, and an app that chooses, clears, disables an
// option and flags an error on a group from outside it.
//
// Every radio group, checkbox and button in every case joins one focus
// group, in reading order: top row left to right, then bottom row. Tab and
// Shift+Tab move focus; the arrows move and choose inside a radio group,
// Space chooses the cursor option, and a click chooses the option under it.
// The status line under the grid shows what the focused case proves; each
// box's own bottom line says what to watch for.

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// CASE
// ═══════════════════════════════════════════════════════════

/// One example case: the widgets it owns, the rule it proves, and the box
/// it paints.
class Case {
  /// Creates a case over [members], with the rule it [proves] and the [box]
  /// it paints.
  Case({required this.proves, required this.members, required this.box});

  /// The rule this case proves, shown on the status line while one of
  /// [members] holds focus.
  final String proves;

  /// The radio groups, checkboxes and buttons this case contributes to the
  /// focus group.
  final List<Component> members;

  /// Renders this case's box. Reads [members] itself to know whether one of
  /// them holds keyboard focus.
  final View Function(Theme theme, StyleResolver resolver) box;
}

/// Wraps [content] in a bordered box titled [title], with [watch] appended
/// below it as a muted caption. The border carries the focus look while
/// [focused].
View _caseBox({
  required String title,
  required String watch,
  required bool focused,
  required StyleResolver resolver,
  required View content,
}) {
  final t = resolver.tones;
  return Container(
    border: BorderType.plain,
    borderStyle: resolver.border({if (focused) WidgetState.focused}),
    topTitles: [Line(' $title ', style: resolver.ink(t.muted))],
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        content,
        Line(watch, style: resolver.ink(t.muted)),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// OPTION LISTS
// ═══════════════════════════════════════════════════════════

/// Three sizes, shared by every preset in [_presetsCase].
List<RadioOption<String>> _sizeOptions() => [
  RadioOption(value: 'Small', label: Line('Small')),
  RadioOption(value: 'Medium', label: Line('Medium')),
  RadioOption(value: 'Large', label: Line('Large')),
];

/// Three sort keys, shared by the vertical and the horizontal group in
/// [_directionCase].
List<RadioOption<String>> _sortOptions() => [
  RadioOption(value: 'Name', label: Line('Name')),
  RadioOption(value: 'Date', label: Line('Date')),
  RadioOption(value: 'Size', label: Line('Size')),
];

/// Three delivery methods, for the form's radio group in [_formCase].
List<RadioOption<String>> _deliveryOptions() => [
  RadioOption(value: 'Home', label: Line('Home delivery')),
  RadioOption(value: 'Pickup', label: Line('Pickup')),
  RadioOption(value: 'Locker', label: Line('Locker')),
];

/// Three shipping speeds, the middle one disabled, for [_skipCase].
List<RadioOption<String>> _shippingOptions() => [
  RadioOption(value: 'Standard', label: Line('Standard')),
  RadioOption(value: 'Express', label: Line('Express'), disabled: true),
  RadioOption(value: 'Overnight', label: Line('Overnight')),
];

/// Three contact methods for [_controlCase], SMS disabled when
/// [smsDisabled] is set.
List<RadioOption<String>> _contactOptions({required bool smsDisabled}) => [
  RadioOption(value: 'Email', label: Line('Email')),
  RadioOption(value: 'Phone', label: Line('Phone')),
  RadioOption(value: 'SMS', label: Line('SMS'), disabled: smsDisabled),
];

// ═══════════════════════════════════════════════════════════
// CASE: PRESET GALLERY
// ═══════════════════════════════════════════════════════════

// Four groups, one per named glyph preset, each offering the same three
// sizes and choosing on its own. The glyphs are the only thing that differs
// between them.

Case _presetsCase(AppModel model) {
  const title = 'Preset gallery';
  const watch = 'four looks; each group chooses on its own';
  final members = [model.presetParen, model.presetDot, model.presetCircle, model.presetOrb];
  return Case(
    proves: 'A glyph preset is a plain field on the model; every group still moves, chooses and paints the same way.',
    members: members,
    box: (theme, resolver) {
      final muted = resolver.ink(resolver.tones.muted);
      View column(String name, RadioGroupModel<String> group) => Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [
          Line(name, style: muted),
          RadioGroup(model: group, theme: theme),
        ],
      );
      return _caseBox(
        title: title,
        watch: watch,
        focused: members.contains(model.focusGroup.focused),
        resolver: resolver,
        content: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: column('paren', model.presetParen)),
            const SizedBox(width: 2),
            Expanded(child: column('dot', model.presetDot)),
            const SizedBox(width: 2),
            Expanded(child: column('circle', model.presetCircle)),
            const SizedBox(width: 2),
            Expanded(child: column('orb', model.presetOrb)),
          ],
        ),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: VERTICAL BESIDE HORIZONTAL
// ═══════════════════════════════════════════════════════════

// The same three sort keys, stacked in a column on the left and laid out on
// one row beside it. `direction` is the only field that differs between the
// two models. A Row hands each group an unbounded width, so both hug their
// own content.

Case _directionCase(AppModel model) {
  const title = 'Vertical beside horizontal';
  const watch = 'horizontal puts the options two cells apart';
  final members = [model.sortVertical, model.sortHorizontal];
  return Case(
    proves:
        '`direction` picks a Column or a Row; the choosing, the wrap and the disabled rule stay the same either way.',
    members: members,
    box: (theme, resolver) => _caseBox(
      title: title,
      watch: watch,
      focused: members.contains(model.focusGroup.focused),
      resolver: resolver,
      content: Row(
        children: [
          RadioGroup(model: model.sortVertical, theme: theme),
          const SizedBox(width: 4),
          RadioGroup(model: model.sortHorizontal, theme: theme),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: SIDE AND ALIGNMENT
// ═══════════════════════════════════════════════════════════

// Four one-option groups, one per labelFirst/labelAlign combination, in one
// stretched column: a bounded parent hands every row the same width, so the
// boxes and the labels line up.

Case _alignmentCase(AppModel model) {
  const title = 'Side and alignment';
  const watch = 'four labelFirst/labelAlign combinations, lined up';
  final members = [model.align1, model.align2, model.align3, model.align4];
  return Case(
    proves: 'A stretched column hands every row the same width, so labelFirst and labelAlign line the rows up.',
    members: members,
    box: (theme, resolver) => _caseBox(
      title: title,
      watch: watch,
      focused: members.contains(model.focusGroup.focused),
      resolver: resolver,
      content: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [for (final m in members) RadioGroup(model: m, theme: theme)],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: A FORM
// ═══════════════════════════════════════════════════════════

// A checkbox, a radio group and a button share one focus group. Tab walks
// all three; the arrows move and choose inside the group without ever
// leaving it. The button reads both the checkbox and the group into the
// result line below it.

Case _formCase(AppModel model) {
  const title = 'A form';
  const watch = 'tab visits three stops; arrows inside the group never move focus off it';
  final members = [model.formTerms, model.formDelivery, model.formSubmit];
  return Case(
    proves: 'One FocusRouter carries Tab across a checkbox, a radio group and a button; the group answers as one stop.',
    members: members,
    box: (theme, resolver) => _caseBox(
      title: title,
      watch: watch,
      focused: members.contains(model.focusGroup.focused),
      resolver: resolver,
      content: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [
          Checkbox(model: model.formTerms, theme: theme),
          const SizedBox(height: 1),
          RadioGroup(model: model.formDelivery, theme: theme),
          const SizedBox(height: 1),
          Button(model: model.formSubmit, theme: theme),
          Line('result: ${model.formResult}', style: resolver.ink(resolver.tones.muted)),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: A DISABLED OPTION
// ═══════════════════════════════════════════════════════════

// One group with its middle option disabled. The keyboard's up and down
// skip it, wrapping between Standard and Overnight; a click on it is
// consumed and chooses nothing.

Case _skipCase(AppModel model) {
  const title = 'A disabled option';
  const watch = 'arrows and clicks skip Express';
  final members = [model.skipGroup];
  return Case(
    proves: 'The cursor and the pointer skip a disabled option; it still paints in place, dimmed.',
    members: members,
    box: (theme, resolver) => _caseBox(
      title: title,
      watch: watch,
      focused: members.contains(model.focusGroup.focused),
      resolver: resolver,
      content: RadioGroup(model: model.skipGroup, theme: theme),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: APP CONTROL
// ═══════════════════════════════════════════════════════════

// Four buttons drive one radio group from outside it: choose a value, clear
// it, disable the SMS option by replacing the option list, and flag an
// error. The status line under the group shows its live value and cursor.

Case _controlCase(AppModel model) {
  const title = 'App control';
  const watch = 'buttons drive the group below';
  final members = [
    model.controlChoose,
    model.controlClear,
    model.controlDisable,
    model.controlError,
    model.controlTarget,
  ];
  return Case(
    proves: 'The app drives value, options and error by writing the fields; the group never edits its own list.',
    members: members,
    box: (theme, resolver) => _caseBox(
      title: title,
      watch: watch,
      focused: members.contains(model.focusGroup.focused),
      resolver: resolver,
      content: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Button(model: model.controlChoose, theme: theme),
              const SizedBox(width: 1),
              Button(model: model.controlClear, theme: theme),
            ],
          ),
          Row(
            children: [
              Button(model: model.controlDisable, theme: theme),
              const SizedBox(width: 1),
              Button(model: model.controlError, theme: theme),
            ],
          ),
          const SizedBox(height: 1),
          RadioGroup(model: model.controlTarget, theme: theme),
          const SizedBox(height: 1),
          Line(
            'value: ${model.controlTarget.value} · cursor: ${model.controlTarget.cursor}',
            style: resolver.ink(resolver.tones.muted),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// APP MODEL
// ═══════════════════════════════════════════════════════════

/// Holds one instance of every case's radio groups, checkboxes and buttons,
/// the focus group and router over all of them, and the small bits of state
/// the app derives from their events.
class AppModel with ThemeSwitcher {
  /// Creates the app's models and wires every case's members into one
  /// [FocusRouter], in reading order.
  AppModel() {
    cases = [
      _presetsCase(this),
      _directionCase(this),
      _alignmentCase(this),
      _formCase(this),
      _skipCase(this),
      _controlCase(this),
    ];
    focusGroup = FocusGroup<Component>([for (final c in cases) ...c.members]);
    router = FocusRouter(focusGroup);
  }

  /// The paren preset: the radio default, three sizes to choose from.
  final RadioGroupModel<String> presetParen = RadioGroupModel(id: 'preset-paren', options: _sizeOptions());

  /// The dot preset: `(•)`, the same three sizes.
  final RadioGroupModel<String> presetDot = RadioGroupModel(
    id: 'preset-dot',
    options: _sizeOptions(),
    glyphs: CheckGlyphs.dot,
  );

  /// The circle preset: no brackets, the same three sizes.
  final RadioGroupModel<String> presetCircle = RadioGroupModel(
    id: 'preset-circle',
    options: _sizeOptions(),
    glyphs: CheckGlyphs.circle,
  );

  /// The orb preset: an emoji mark, the same three sizes.
  final RadioGroupModel<String> presetOrb = RadioGroupModel(
    id: 'preset-orb',
    options: _sizeOptions(),
    glyphs: CheckGlyphs.orb,
  );

  /// A vertical sort-order group: one option per row.
  final RadioGroupModel<String> sortVertical = RadioGroupModel(id: 'sort-vertical', options: _sortOptions());

  /// The same sort-order options, laid out on one row.
  final RadioGroupModel<String> sortHorizontal = RadioGroupModel(
    id: 'sort-horizontal',
    options: _sortOptions(),
    direction: Axis.horizontal,
  );

  /// Box first, label at the row's start — the default layout.
  final RadioGroupModel<int> align1 = RadioGroupModel(
    id: 'align-1',
    options: [RadioOption(value: 1, label: Line('Option 1'))],
  );

  /// Box first, label pushed to the row's end.
  final RadioGroupModel<int> align2 = RadioGroupModel(
    id: 'align-2',
    options: [RadioOption(value: 1, label: Line('Option 1'))],
    labelAlign: TextAlign.end,
  );

  /// Label first, label at the row's start, so the box trails.
  final RadioGroupModel<int> align3 = RadioGroupModel(
    id: 'align-3',
    options: [RadioOption(value: 1, label: Line('Option 1'))],
    labelFirst: true,
  );

  /// Label first, label pushed to the row's end, so the box sits between
  /// the spare width and the label.
  final RadioGroupModel<int> align4 = RadioGroupModel(
    id: 'align-4',
    options: [RadioOption(value: 1, label: Line('Option 1'))],
    labelFirst: true,
    labelAlign: TextAlign.end,
  );

  /// The form's terms checkbox.
  final CheckboxModel formTerms = CheckboxModel(id: 'form-terms', label: Line('Accept the terms'));

  /// The form's delivery method, one exclusive choice among three.
  final RadioGroupModel<String> formDelivery = RadioGroupModel(id: 'form-delivery', options: _deliveryOptions());

  /// The form's submit button.
  final ButtonModel formSubmit = ButtonModel(id: 'form-submit', label: Line('Submit'));

  /// The last result the form's submit button produced.
  String formResult = 'not submitted yet';

  /// A shipping-speed group with its middle option, "Express", disabled.
  final RadioGroupModel<String> skipGroup = RadioGroupModel(id: 'skip-group', options: _shippingOptions());

  /// Chooses a value on [controlTarget].
  final ButtonModel controlChoose = ButtonModel(id: 'control-choose', label: Line('Choose phone'));

  /// Clears [controlTarget]'s value.
  final ButtonModel controlClear = ButtonModel(id: 'control-clear', label: Line('Clear'));

  /// Toggles whether [controlTarget]'s SMS option is disabled.
  final ButtonModel controlDisable = ButtonModel(id: 'control-disable', label: Line('Toggle disable SMS'));

  /// Toggles [controlTarget]'s error flag.
  final ButtonModel controlError = ButtonModel(id: 'control-error', label: Line('Toggle error'));

  /// The contact-method group the four buttons above drive.
  final RadioGroupModel<String> controlTarget = RadioGroupModel(
    id: 'control-target',
    options: _contactOptions(smsDisabled: false),
    direction: Axis.horizontal,
  );

  /// Every case, in reading order: top row left to right, then bottom row.
  late final List<Case> cases;

  /// Every radio group, checkbox and button, in the same reading order Tab
  /// walks.
  late final FocusGroup<Component> focusGroup;

  /// Routes keyboard and pointer traffic among every case's members.
  late final FocusRouter router;

  /// The case the currently focused member belongs to.
  Case get focusedCase => cases.firstWhere((c) => c.members.contains(focusGroup.focused));
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

/// Reads one widget event the router produced and applies its effect: the
/// form's submit button and the app-control buttons.
void _onEvent(AppModel model, WidgetEvent event) {
  switch (event) {
    case ButtonPressEvent(id: 'form-submit'):
      model.formResult = 'terms ${model.formTerms.checked} · delivery ${model.formDelivery.value}';
    case ButtonPressEvent(id: 'control-choose'):
      model.controlTarget.value = 'Phone';
    case ButtonPressEvent(id: 'control-clear'):
      model.controlTarget.value = null;
    case ButtonPressEvent(id: 'control-disable'):
      // RadioOption is immutable and the model never edits its list, so
      // the app replaces the whole list with the SMS flag flipped.
      final smsDisabled = model.controlTarget.options.last.disabled;
      model.controlTarget.options = _contactOptions(smsDisabled: !smsDisabled);
    case ButtonPressEvent(id: 'control-error'):
      model.controlTarget.error = !model.controlTarget.error;
    default:
      break;
  }
}

/// The app's `update`: the router first, then the quit key on whatever it
/// declines.
(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext ctx) {
  if (model.handleThemeSwitch(msg)) {
    return (model, null);
  }

  switch (model.router.route(msg, ctx)) {
    case Handled(:final events, :final cmd):
      for (final event in events) {
        _onEvent(model, event);
      }
      return (model, cmd);
    case Declined():
      break; // not interaction traffic — fall through to the quit key
  }

  if (msg case KeyMsg(key: 'q')) return (model, const Quit());
  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

View _header(StyleResolver resolver) => Line(
  'tab/shift+tab focus · arrows/space choose · click chooses a row · F1/F2 theme · q quit',
  style: resolver.ink(resolver.tones.muted),
);

/// The focused case's rule, on its own line under the app's own state.
View _status(AppModel model, StyleResolver resolver) {
  final muted = resolver.ink(resolver.tones.muted);
  return Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Line('theme: ${model.theme.name}   focus: ${model.focusGroup.focused.id}', style: muted),
      Line('proves: ${model.focusedCase.proves}', style: muted),
    ],
  );
}

/// The app's `view`: a header, a grid of one box per case, and the status
/// line.
void view(AppModel model, Frame frame) {
  final theme = model.theme;
  final resolver = StyleResolver(theme);
  final t = resolver.tones;
  frame.buffer.setStyle(frame.area, resolver.ground(t.background));

  final boxes = [for (final c in model.cases) c.box(theme, resolver)];

  final grid = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: boxes[0]),
            Expanded(child: boxes[1]),
            Expanded(child: boxes[2]),
          ],
        ),
      ),
      const SizedBox(height: 1),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: boxes[3]),
            Expanded(child: boxes[4]),
            Expanded(child: boxes[5]),
          ],
        ),
      ),
    ],
  );

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      _header(resolver),
      const SizedBox(height: 1),
      Expanded(child: grid),
      const SizedBox(height: 1),
      _status(model, resolver),
    ],
  );

  frame.render(ui);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Radio group', mouseEvents: true).run(
      init: AppModel(),
      update: update,
      view: view,
    ),
  );
}
