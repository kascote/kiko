import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'main.dart';
import 'shared.dart';

// Page 2: the live gallery. The shipped widgets render under the same
// theme as the reference page, wired to the app model, so Tab moves focus
// through them and each tone can be watched doing its job.

/// Page 2 of the theme viewer: the live gallery.
///
/// A form column sits on the left; a list, a tree, and a table fill the
/// rest of the row, each in its own bordered pane. [comboView] is built
/// once by the caller and passed in, since a fresh [Combobox] every frame
/// would lose the popup's own paint state.
View galleryPage(Model model, Theme theme, StyleResolver resolver, View comboView) => Row(
  crossAxis: CrossAxisAlignment.stretch,
  children: [
    _formColumn(model, theme, resolver, comboView),
    Expanded(child: _pane(resolver, 'ListView', model.list.focused, _listView(model, theme))),
    Expanded(
      child: _pane(resolver, 'TreeView', model.tree.focused, TreeView(model: model.tree, theme: theme)),
    ),
    Expanded(
      child: _pane(
        resolver,
        'TableView',
        model.table.focused,
        Column(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TableView(
                model: model.table,
                theme: theme,
                pendingBuilder: (_) => Line('Loading…'),
                emptyPlaceholder: Line('No rows'),
                showCrosshair: true,
              ),
            ),
            Line(
              'crosshair: a wash; drops under ANSI-16 and NO_COLOR by design',
              style: resolver.ink(resolver.tones.muted),
            ),
          ],
        ),
      ),
    ),
  ],
);

/// The form column: text inputs in three states, the combobox, the editor,
/// the button row, and a checkbox row.
View _formColumn(Model model, Theme theme, StyleResolver resolver, View comboView) {
  final requiredStates = {
    if (model.requiredInput.focused) WidgetState.focused,
    if (model.requiredInput.error) WidgetState.error,
  };
  return ConstrainedBox(
    additionalConstraints: const BoxConstraints(minW: 36, maxW: 36),
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        _field(
          resolver,
          'TextInput',
          {if (model.name.focused) WidgetState.focused},
          TextInput(model: model.name, theme: theme),
        ),
        _field(
          resolver,
          'TextInput — required',
          requiredStates,
          TextInput(model: model.requiredInput, theme: theme),
        ),
        _field(
          resolver,
          'TextInput — disabled',
          const {WidgetState.disabled},
          TextInput(model: model.disabledInput, theme: theme),
        ),
        _field(resolver, 'Combobox', {if (model.combo.focused) WidgetState.focused}, comboView),
        Expanded(
          child: Container(
            border: BorderType.plain,
            borderStyle: resolver.border({if (model.editor.focused) WidgetState.focused}),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [
              Line(' TextArea ', style: titleInk(resolver, {if (model.editor.focused) WidgetState.focused})),
            ],
            child: TextArea(model: model.editor, theme: theme),
          ),
        ),
        Row(
          children: [
            Button(model: model.okButton, theme: theme),
            const SizedBox(width: 1),
            Button(model: model.offButton, theme: theme),
            const SizedBox(width: 1),
            Button(
              model: model.dialogButton,
              theme: theme,
              style: ButtonStyle(face: resolver.fill(resolver.tones.error)),
            ),
          ],
        ),
        Checkbox(model: model.agree, theme: theme),
      ],
    ),
  );
}

/// A bordered, titled, one-row field. The border carries [states] — focus,
/// error, and disabled all read from it.
View _field(StyleResolver resolver, String title, Set<WidgetState> states, View child) => Container(
  border: BorderType.plain,
  borderStyle: resolver.border(states),
  padding: const EdgeInsets.symmetric(horizontal: 1),
  topTitles: [Line(' $title ', style: titleInk(resolver, states))],
  child: ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
    child: child,
  ),
);

/// A bordered gallery pane; the border and the title show the focus state.
View _pane(StyleResolver resolver, String title, bool focused, View child) => Container(
  border: BorderType.plain,
  borderStyle: resolver.border({if (focused) WidgetState.focused}),
  topTitles: [
    Line(' $title ', style: titleInk(resolver, {if (focused) WidgetState.focused})),
  ],
  child: child,
);

View _listView(Model model, Theme theme) => ListView(
  model: model.list,
  theme: theme,
  itemBuilder: (chore, index, state) => [
    Line(' ${state.selected ? '●' : '○'} $chore'),
  ],
);
