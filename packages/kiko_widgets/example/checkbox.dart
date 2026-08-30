// This example runs every case a checkbox covers: the glyph presets, custom
// per-part colors, the label/box layouts lined up two different ways, a form
// wired through one FocusRouter, a select-all parent with a mixed state, and
// an app that checks, unchecks, disables and clears an error on a checkbox
// from outside it.
//
// Every checkbox and button in every case joins one focus group, in reading
// order: top row left to right, then bottom row. Tab and Shift+Tab move
// focus; Space and a click both toggle. The status line under the grid shows
// what the focused case proves; each box's own bottom line says what to
// watch for.

import 'dart:io';
import 'dart:math' show max;

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// CASE
// ═══════════════════════════════════════════════════════════

/// One example case: the checkboxes and buttons it owns, the rule it
/// proves, and the box it paints.
class Case {
  /// Creates a case over [members], with the rule it [proves] and the [box]
  /// it paints.
  Case({required this.proves, required this.members, required this.box});

  /// The rule this case proves, shown on the status line while one of
  /// [members] holds focus.
  final String proves;

  /// The checkboxes and buttons this case contributes to the focus group.
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
// CASE: PRESET GALLERY
// ═══════════════════════════════════════════════════════════

// Six checkboxes, one per named glyph preset, each toggling on its own. The
// glyphs are the only thing that differs between them.

Case _presetsCase(AppModel model) {
  const title = 'Preset gallery';
  const watch = 'six presets, six looks; each toggles on its own';
  final members = model.presets;
  return Case(
    proves: 'A glyph preset is a plain string swap; layout and toggling stay identical.',
    members: members,
    box: (theme, resolver) => _caseBox(
      title: title,
      watch: watch,
      focused: members.contains(model.focusGroup.focused),
      resolver: resolver,
      content: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [for (final c in members) Checkbox(model: c, theme: theme)],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: PER-PART COLORS
// ═══════════════════════════════════════════════════════════

// The top row gives open, close, mark, checkedMark and label each a
// different tone. The bottom row builds the block preset's "filled button"
// look: the bracket tone as fill on the mark, so the mark cell reads as a
// solid button between the two half blocks, and as ink on the brackets
// themselves. The app derives both style sets from the theme in `update`,
// on start and on every theme switch; the view only reads them.

Case _colorsCase(AppModel model) {
  const title = 'Per-part colors';
  const watch = 'top row: one tone per part. bottom row: a filled mark';
  final members = [model.colorsParts, model.colorsBlock];
  return Case(
    proves: 'Every glyph part has its own style slot; a fill on the bracket tone reads as a filled button.',
    members: members,
    box: (theme, resolver) => _caseBox(
      title: title,
      watch: watch,
      focused: members.contains(model.focusGroup.focused),
      resolver: resolver,
      content: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [for (final m in members) Checkbox(model: m, theme: theme)],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: A FORM
// ═══════════════════════════════════════════════════════════

// Three checkboxes and a button share one focus group. Tab walks all four;
// Space and a click both toggle a checkbox; the button reads every
// checkbox's value into the result line below it.

Case _formCase(AppModel model) {
  const title = 'A form';
  const watch = 'tab cycles all four; submit reads every checkbox';
  final members = [model.formTerms, model.formNewsletter, model.formUpdates, model.formSubmit];
  return Case(
    proves: 'One FocusRouter carries Tab and Space across checkboxes and a button alike.',
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
          Checkbox(model: model.formNewsletter, theme: theme),
          Checkbox(model: model.formUpdates, theme: theme),
          const SizedBox(height: 1),
          Button(model: model.formSubmit, theme: theme),
          Line('result: ${model.formResult}', style: resolver.ink(resolver.tones.muted)),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: LINING ROWS UP
// ═══════════════════════════════════════════════════════════

// The left column shows the four labelFirst/labelAlign combinations under an
// Expanded cell: a stretched Column fills the width a bounded parent hands
// it. The right column shows the other way: rows of differing label
// lengths, hugged to the widest one through a ConstrainedBox sized from
// CheckboxModel.width — the width a plain Column cannot compute on its own.

Case _alignmentCase(AppModel model) {
  const title = 'Lining rows up';
  const watch = 'left: one stretched column. right: sized to its own widest row';
  final members = [...model.alignColumnA, ...model.alignColumnB];
  return Case(
    proves: 'A stretched column fills a bound width; a ConstrainedBox sized from width(measurer) hugs the widest row.',
    members: members,
    box: (theme, resolver) => _caseBox(
      title: title,
      watch: watch,
      focused: members.contains(model.focusGroup.focused),
      resolver: resolver,
      content: Row(
        children: [
          Expanded(
            child: Column(
              crossAxis: CrossAxisAlignment.stretch,
              children: [for (final m in model.alignColumnA) Checkbox(model: m, theme: theme)],
            ),
          ),
          const SizedBox(width: 3),
          ConstrainedBox(
            additionalConstraints: BoxConstraints(minW: model.alignColumnBWidth, maxW: model.alignColumnBWidth),
            child: Column(
              crossAxis: CrossAxisAlignment.stretch,
              children: [for (final m in model.alignColumnB) Checkbox(model: m, theme: theme)],
            ),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: SELECT-ALL WITH MIXED
// ═══════════════════════════════════════════════════════════

// A parent checkbox over three children. The app watches every child change
// and writes the parent's state: mixed while some are checked, checked when
// every one is, unchecked when none are. Toggling the parent itself checks
// or unchecks every child at once — from mixed, a toggle goes to checked,
// so it always checks the group.

Case _selectAllCase(AppModel model) {
  const title = 'Select-all with mixed';
  const watch = 'check one child: parent goes mixed. check the rest: parent goes checked';
  final members = [model.selectAllParent, ...model.selectAllChildren];
  return Case(
    proves: 'The app writes state = mixed from the children; toggling the parent from mixed checks every child.',
    members: members,
    box: (theme, resolver) => _caseBox(
      title: title,
      watch: watch,
      focused: members.contains(model.focusGroup.focused),
      resolver: resolver,
      content: Column(
        crossAxis: CrossAxisAlignment.stretch,
        children: [
          Checkbox(model: model.selectAllParent, theme: theme),
          const SizedBox(height: 1),
          for (final child in model.selectAllChildren) Checkbox(model: child, theme: theme),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// CASE: APP CONTROL
// ═══════════════════════════════════════════════════════════

// Three buttons drive one checkbox from outside it: check, uncheck, and
// toggle disabled. A disabled checkbox keeps its value and shows it,
// dimmed — it just stops answering the keyboard and the pointer. The second
// checkbox starts in error and stays that way until the app clears the flag
// on its own change event.

Case _controlCase(AppModel model) {
  const title = 'App control';
  const watch = 'check/uncheck/toggle drive the target; confirm starts red until checked';
  final members = [
    model.controlCheck,
    model.controlUncheck,
    model.controlToggleDisable,
    model.controlTarget,
    model.controlConfirm,
  ];
  return Case(
    proves: 'The app drives checked, disabled and error by writing the field; disabled keeps the value, dimmed.',
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
              Button(model: model.controlCheck, theme: theme),
              const SizedBox(width: 1),
              Button(model: model.controlUncheck, theme: theme),
              const SizedBox(width: 1),
              Button(model: model.controlToggleDisable, theme: theme),
            ],
          ),
          const SizedBox(height: 1),
          Checkbox(model: model.controlTarget, theme: theme),
          const SizedBox(height: 1),
          Checkbox(model: model.controlConfirm, theme: theme),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// APP MODEL
// ═══════════════════════════════════════════════════════════

/// Holds one instance of every case's checkboxes and buttons, the focus
/// group and router over all of them, and the small bits of state the app
/// derives from their events.
class AppModel with ThemeSwitcher {
  /// Creates the app's models and wires every case's members into one
  /// [FocusRouter], in reading order.
  AppModel() {
    cases = [
      _presetsCase(this),
      _colorsCase(this),
      _formCase(this),
      _alignmentCase(this),
      _selectAllCase(this),
      _controlCase(this),
    ];
    focusGroup = FocusGroup<Component>([for (final c in cases) ...c.members]);
    router = FocusRouter(focusGroup);
    applyTheme();
  }

  /// One checkbox per named glyph preset.
  final List<CheckboxModel> presets = [
    CheckboxModel(id: 'preset-ascii', label: Line('ascii')),
    CheckboxModel(id: 'preset-check', label: Line('check'), glyphs: CheckGlyphs.check),
    CheckboxModel(id: 'preset-ballot', label: Line('ballot'), glyphs: CheckGlyphs.ballot),
    CheckboxModel(id: 'preset-square', label: Line('square'), glyphs: CheckGlyphs.square),
    CheckboxModel(id: 'preset-block', label: Line('block'), glyphs: CheckGlyphs.block),
    CheckboxModel(id: 'preset-emoji', label: Line('emoji'), glyphs: CheckGlyphs.emoji),
  ];

  /// A checkbox with a custom glyph set and a different tone on every part.
  final CheckboxModel colorsParts = CheckboxModel(
    id: 'colors-parts',
    label: Line('Every part its own tone'),
    glyphs: const CheckGlyphs(open: '⟨', close: '⟩', checked: '✓', unchecked: '·', mixed: '≈'),
  );

  /// The block preset styled as a filled button.
  final CheckboxModel colorsBlock = CheckboxModel(
    id: 'colors-block',
    label: Line('A filled button between the blocks'),
    glyphs: CheckGlyphs.block,
  );

  /// The form's terms checkbox.
  final CheckboxModel formTerms = CheckboxModel(id: 'form-terms', label: Line('Accept the terms'));

  /// The form's newsletter checkbox.
  final CheckboxModel formNewsletter = CheckboxModel(id: 'form-newsletter', label: Line('Send me the newsletter'));

  /// The form's updates checkbox.
  final CheckboxModel formUpdates = CheckboxModel(id: 'form-updates', label: Line('Notify me of updates'));

  /// The form's submit button.
  final ButtonModel formSubmit = ButtonModel(id: 'form-submit', label: Line('Submit'));

  /// The last result the form's submit button produced.
  String formResult = 'not submitted yet';

  /// The four labelFirst/labelAlign combinations, sharing one label so the
  /// stretched column's alignment is easy to read.
  final List<CheckboxModel> alignColumnA = [
    CheckboxModel(id: 'align-a1', label: Line('Option 1')),
    CheckboxModel(id: 'align-a2', label: Line('Option 1'), labelAlign: TextAlign.end),
    CheckboxModel(id: 'align-a3', label: Line('Option 1'), labelFirst: true),
    CheckboxModel(id: 'align-a4', label: Line('Option 1'), labelFirst: true, labelAlign: TextAlign.end),
  ];

  /// The same four combinations, with labels of differing lengths, so
  /// [alignColumnBWidth] is doing real work.
  final List<CheckboxModel> alignColumnB = [
    CheckboxModel(id: 'align-b1', label: Line('Wifi')),
    CheckboxModel(id: 'align-b2', label: Line('Bluetooth'), labelAlign: TextAlign.end),
    CheckboxModel(id: 'align-b3', label: Line('Location services'), labelFirst: true),
    CheckboxModel(id: 'align-b4', label: Line('Sync'), labelFirst: true, labelAlign: TextAlign.end),
  ];

  /// The width of [alignColumnB]'s widest row, measured once: the number a
  /// `ConstrainedBox` needs so the column hugs its content instead of
  /// filling the whole box.
  late final int alignColumnBWidth = alignColumnB.map((m) => m.width(const TermUnicodeMeasurer())).reduce(max);

  /// The select-all parent.
  final CheckboxModel selectAllParent = CheckboxModel(id: 'select-all-parent', label: Line('Select all'));

  /// The select-all children.
  final List<CheckboxModel> selectAllChildren = [
    CheckboxModel(id: 'select-all-1', label: Line('Item 1')),
    CheckboxModel(id: 'select-all-2', label: Line('Item 2')),
    CheckboxModel(id: 'select-all-3', label: Line('Item 3')),
  ];

  /// Checks [controlTarget].
  final ButtonModel controlCheck = ButtonModel(id: 'control-check', label: Line('Check'));

  /// Unchecks [controlTarget].
  final ButtonModel controlUncheck = ButtonModel(id: 'control-uncheck', label: Line('Uncheck'));

  /// Flips [controlTarget]'s disabled flag.
  final ButtonModel controlToggleDisable = ButtonModel(id: 'control-toggle-disable', label: Line('Toggle disable'));

  /// The checkbox the three buttons above drive.
  final CheckboxModel controlTarget = CheckboxModel(id: 'control-target', label: Line('Target'));

  /// Starts in error; the app clears the flag once this checkbox changes.
  final CheckboxModel controlConfirm = CheckboxModel(
    id: 'control-confirm',
    label: Line('Confirm to continue'),
    error: true,
  );

  /// Every case, in reading order: top row left to right, then bottom row.
  late final List<Case> cases;

  /// Every checkbox and button, in the same reading order Tab walks.
  late final FocusGroup<Component> focusGroup;

  /// Routes keyboard and pointer traffic among every case's members.
  late final FocusRouter router;

  /// The case the currently focused member belongs to.
  Case get focusedCase => cases.firstWhere((c) => c.members.contains(focusGroup.focused));

  /// Derives the per-part-colors case's two style sets from the current
  /// theme.
  ///
  /// The app calls this once, at construction, and again on every theme
  /// switch, so [colorsParts] and [colorsBlock] always carry tones from the
  /// theme in force.
  void applyTheme() {
    final resolver = StyleResolver(theme);
    final t = resolver.tones;
    colorsParts.styles = CheckboxStyle(
      open: resolver.ink(t.primary),
      close: resolver.ink(t.secondary),
      mark: resolver.ink(t.accent),
      checkedMark: resolver.ink(t.success),
      label: resolver.ink(t.warning),
    );
    colorsBlock.styles = CheckboxStyle(
      open: resolver.ink(t.accent),
      close: resolver.ink(t.accent),
      mark: resolver.fill(t.accent),
      checkedMark: resolver.fill(t.accent),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

/// Reads one widget event the router produced and applies its effect: the
/// select-all wiring, the error-clearing confirm checkbox, and the form and
/// app-control buttons.
void _onEvent(AppModel model, WidgetEvent event) {
  switch (event) {
    case CheckboxChangeEvent(id: 'select-all-parent', :final checked):
      for (final child in model.selectAllChildren) {
        child.checked = checked;
      }
    case CheckboxChangeEvent(:final id) when model.selectAllChildren.any((c) => c.id == id):
      final checkedCount = model.selectAllChildren.where((c) => c.checked).length;
      model.selectAllParent.state = switch (checkedCount) {
        0 => CheckState.unchecked,
        final n when n == model.selectAllChildren.length => CheckState.checked,
        _ => CheckState.mixed,
      };
    case CheckboxChangeEvent(id: 'control-confirm'):
      model.controlConfirm.error = false;
    case ButtonPressEvent(id: 'form-submit'):
      model.formResult =
          'terms ${model.formTerms.checked} · newsletter ${model.formNewsletter.checked} · '
          'updates ${model.formUpdates.checked}';
    case ButtonPressEvent(id: 'control-check'):
      model.controlTarget.checked = true;
    case ButtonPressEvent(id: 'control-uncheck'):
      model.controlTarget.checked = false;
    case ButtonPressEvent(id: 'control-toggle-disable'):
      model.controlTarget.disabled = !model.controlTarget.disabled;
    default:
      break;
  }
}

/// The app's `update`: the router first, then the quit key on whatever it
/// declines.
(AppModel, Cmd?) update(AppModel model, Msg msg, UpdateContext ctx) {
  if (model.handleThemeSwitch(msg)) {
    model.applyTheme();
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
  'tab/shift+tab focus · space/click toggle · F1/F2 theme · q quit',
  style: resolver.ink(resolver.tones.muted),
);

/// The focused case's rule, on its own line under the app's own state.
View _status(AppModel model, StyleResolver resolver) {
  final muted = resolver.ink(resolver.tones.muted);
  return Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Line('theme: ${model.themeName}   focus: ${model.focusGroup.focused.id}', style: muted),
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
    await Application(title: 'Checkbox', mouseEvents: true).run(
      init: AppModel(),
      update: update,
      view: view,
    ),
  );
}
