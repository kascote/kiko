import 'package:kiko/kiko.dart';

import 'main.dart';
import 'shared.dart';

// Page 4: the states. Every migrated widget is forced into each state, once
// on the window and once on a surface panel standing for a dialog, so the
// same widget can be compared across the two grounds. The page is the
// acceptance check for a widget's look: a widget is done when each of its
// rows reads right here, on every theme and every tier.
//
// A widget joins the page by adding one section function below and its models
// to [StatesHalf]. Each half owns its own models, since one model rendered
// twice would repeat its hit id.

/// The widget models of one half of the states page.
///
/// The window half and the dialog half each hold their own instance, with ids
/// that start with [prefix] so the two never share a hit id. A widget's batch
/// adds its models here.
class StatesHalf {
  /// Creates the models of one half, with every id starting with [prefix].
  StatesHalf(this.prefix);

  /// The id prefix of this half: `win.` for the window, `dlg.` for the dialog.
  final String prefix;
}

/// The two halves of the states page.
class StatesModel {
  /// The models drawn on the window ground.
  final StatesHalf window = StatesHalf('win.');

  /// The models drawn on the surface panel.
  final StatesHalf dialog = StatesHalf('dlg.');
}

/// The width of the row-label column.
const int _labelWidth = 12;

/// The states every widget row shows, in order.
const List<String> _stateRows = ['rest', 'focused', 'hover', 'pressed', 'disabled'];

/// Page 4 of the theme viewer: the states.
///
/// The left half paints on the window ground of [resolver]. The right half is
/// a bordered panel on the surface ground, and every widget in it receives a
/// resolver bound to that ground. Both halves show the same sections.
View statesPage(Model model, StyleResolver resolver) {
  final surface = resolver.on(resolver.tones.surface);
  return Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _window(resolver, model.states.window)),
            const SizedBox(width: 1),
            Expanded(child: _dialog(surface, model.states.dialog)),
          ],
        ),
      ),
      Line(
        'Each row forces one state. Compare a row on the window with the same row on the surface panel.',
        style: resolver.ink(resolver.tones.accent),
      ),
      Line(
        '${model.theme.name} · ${model.tierName} · Page ${model.page}/4: ${model.pageName} · '
        'step ${Theme.step.toStringAsFixed(2)} · de-emphasis ${model.theme.deEmphasis.toStringAsFixed(2)}',
        style: resolver.ink(resolver.tones.muted),
      ),
    ],
  );
}

/// The window half: a plain border on the frame's own ground.
View _window(StyleResolver r, StatesHalf half) => Container(
  border: BorderType.plain,
  borderStyle: r.border(const {}),
  padding: const EdgeInsets.symmetric(horizontal: 1),
  topTitles: [Line(' Window, on background ', style: r.ink(r.tones.muted))],
  child: _sections(r, half),
);

/// The dialog half: a rounded border on the surface ground. [r] is bound to
/// the surface, so its border, its labels and its widgets all read from it.
View _dialog(StyleResolver r, StatesHalf half) => Container(
  border: BorderType.rounded,
  borderStyle: r.border(const {}),
  ground: r.ground(r.tones.surface),
  padding: const EdgeInsets.symmetric(horizontal: 1),
  topTitles: [Line(' Dialog, on surface ', style: r.ink(r.tones.muted))],
  child: _sections(r, half),
);

/// Every widget section of one half, stacked from the top.
View _sections(StyleResolver r, StatesHalf half) => Column(
  crossAxis: CrossAxisAlignment.stretch,
  children: [
    ..._buttonSection(r, half),
    ..._checkboxSection(r, half),
    ..._radioGroupSection(r, half),
  ],
);

List<View> _buttonSection(StyleResolver r, StatesHalf half) => _section(r, 'Button', _placeholderRows(r));

List<View> _checkboxSection(StyleResolver r, StatesHalf half) => _section(r, 'Checkbox', _placeholderRows(r));

List<View> _radioGroupSection(StyleResolver r, StatesHalf half) => _section(r, 'RadioGroup', _placeholderRows(r));

/// A section: its title, then its labelled rows.
List<View> _section(StyleResolver r, String title, List<View> rows) => [
  Line(title, style: r.ink(r.tones.primary).copyWith(addModifier: Modifier.bold)),
  ...rows,
  const SizedBox(height: 1),
];

/// One labelled row: the state's name, then the widget forced into it.
View _row(StyleResolver r, String label, View widget) => Row(
  children: [
    col(_labelWidth, Line(label, style: r.ink(r.tones.muted))),
    Expanded(child: widget),
  ],
);

/// The rows of a widget whose batch has not landed: the state names and a
/// muted line saying so.
List<View> _placeholderRows(StyleResolver r) => [
  for (final label in _stateRows) _row(r, label, Line('— added by its batch —', style: r.ink(r.tones.muted))),
];
