import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

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
/// adds its models here. Each model map holds one forced model per name in
/// [_stateRows].
class StatesHalf {
  /// Creates the models of one half, with every id starting with [prefix].
  StatesHalf(this.prefix)
    : buttons = {
        for (final state in _stateRows)
          state: ButtonModel(id: '${prefix}button.$state', label: Line('Save'), focused: state == 'focused')
            ..hovered = state == 'hover'
            ..pressed = state == 'pressed'
            ..disabled = state == 'disabled',
      },
      checkboxes = {
        for (final state in _stateRows)
          state:
              CheckboxModel(
                  id: '${prefix}checkbox.$state',
                  label: Line('Notify me'),
                  state: CheckState.checked,
                  focused: state == 'focused',
                )
                ..hovered = state == 'hover'
                ..pressed = state == 'pressed'
                ..disabled = state == 'disabled',
      },
      radioGroups = {
        for (final state in _stateRows)
          state:
              RadioGroupModel<int>(
                  id: '${prefix}radio.$state',
                  value: 0,
                  options: [
                    RadioOption(value: 0, label: Line('Daily')),
                    RadioOption(value: 1, label: Line('Weekly')),
                  ],
                  focused: state == 'focused',
                )
                ..hoveredIndex = state == 'hover' ? 0 : null
                ..pressedIndex = state == 'pressed' ? 0 : null
                ..disabled = state == 'disabled',
      },
      textInputs = {
        for (final state in _inputRows)
          state: TextInputModel(
            id: '${prefix}input.$state',
            initial: state == 'placeholder' ? '' : 'ada@example.com',
            placeholder: 'name@example.com',
            focused: state == 'focused',
            disabled: state == 'disabled',
          ),
      },
      errorInput = TextInputModel(id: '${prefix}input.error', initial: 'ada@example', error: true),
      cursorList = _forcedList('${prefix}list.cursor', focused: false),
      focusedList = ListViewModel<String, String>(
        id: '${prefix}list.focused',
        items: const [_focusedRow],
        focused: true,
      ),
      cursorTable = _forcedTable('${prefix}table.cursor', rows: _tableRows.length, focused: false),
      focusedTable = _forcedTable('${prefix}table.focused', rows: 1, focused: true),
      cursorTree = _forcedTree('${prefix}tree.cursor'),
      focusedTree = _focusedTree('${prefix}tree.focused'),
      combobox = _openCombobox('${prefix}combo');

  /// The id prefix of this half: `win.` for the window, `dlg.` for the dialog.
  final String prefix;

  /// The buttons, one per state row.
  final Map<String, ButtonModel> buttons;

  /// The checked checkboxes, one per state row.
  final Map<String, CheckboxModel> checkboxes;

  /// The radio groups, option 0 chosen, one per state row.
  final Map<String, RadioGroupModel<int>> radioGroups;

  /// The text inputs, one per name in [_inputRows].
  final Map<String, TextInputModel> textInputs;

  /// An input with the error fact set. The field paints nothing for it, so
  /// the row composes a border that reads it.
  final TextInputModel errorInput;

  /// The list holding one row per state of [_listRows], its cursor on the
  /// `cursor` row and its list not focused.
  final ListViewModel<String, String> cursorList;

  /// A one-row list that owns focus, so its cursor row paints focused.
  final ListViewModel<String, String> focusedList;

  /// The table holding one row per state of [_tableRows], its cursor on the
  /// `cursor` row and its table not focused.
  final TableViewModel cursorTable;

  /// A one-row table that owns focus, so its cursor cell paints focused.
  final TableViewModel focusedTable;

  /// The tree holding one node per state of [_treeRows], its cursor on the
  /// `cursor` node and its tree not focused.
  final TreeViewModel<String> cursorTree;

  /// A one-node tree that owns focus, so its cursor row paints focused.
  final TreeViewModel<String> focusedTree;

  /// A focused combobox with its popup open.
  final ComboboxModel<String> combobox;
}

/// The text of the focused-cursor list row.
const String _focusedRow = 'cursor (focused)';

/// The rows of the state list, in order. The row's text names its state.
const List<String> _listRows = ['rest', 'cursor (unfocused)', 'selected', 'selected + error cell', 'hover', 'disabled'];

/// Builds the state list: a multi-select list with rows 2 and 3 selected, the
/// cursor on row 1, the pointer over row 4 and row 5 disabled.
ListViewModel<String, String> _forcedList(String id, {required bool focused}) =>
    // The model refuses keys while unfocused, so it starts focused, selects, and blurs after.
    ListViewModel<String, String>(
        id: id,
        items: _listRows,
        multiSelect: true,
        isDisabled: (index) => index == 5,
        focused: true,
      )
      ..moveCursorTo(2)
      ..update(const KeyMsg('space'))
      ..moveCursorTo(3)
      ..update(const KeyMsg('space'))
      ..moveCursorTo(1)
      ..hoverRow = 4
      ..focused = focused;

/// The text of the focused-cursor table row.
const String _focusedTableRow = 'cursor (focused)';

/// The rows of the state table, in order. The first column names the state.
const List<String> _tableRows = ['rest', 'cursor (unfocused)', 'selected', 'selected + error', 'hover'];

/// The columns of the state tables. `qty` carries a column ink that must
/// survive selection, and `flag` shows its error ink on one row only.
List<TableColumn> _tableColumns() => [
  TableColumn(field: 'name', label: Line('state'), width: 18),
  TableColumn(
    field: 'qty',
    label: Line('qty'),
    width: 3,
    alignment: TextAlign.end,
    style: (r) => r.ink(r.tones.success),
  ),
  TableColumn(
    field: 'flag',
    label: Line('flag'),
    width: 4,
    style: (r) => r.resolve(null, const {WidgetState.error}, cls: PaintClass.ink),
  ),
];

/// Builds a state table of [rows] rows. With four or more rows it is the
/// multi-select table: rows 2 and 3 selected, the cursor on row 1, the
/// pointer over row 4. With one row the cursor sits on it.
TableViewModel _forcedTable(String id, {required int rows, required bool focused}) {
  final data = [
    for (var i = 0; i < rows; i++)
      {
        'id': 'r$i',
        'name': rows == 1 ? _focusedTableRow : _tableRows[i],
        'qty': '${i + 1}',
        'flag': rows > 1 && i == 3 ? 'err' : '',
      },
  ];
  final model = TableViewModel(
    id: id,
    keyField: 'id',
    columns: _tableColumns(),
    rows: data,
    selectionEnabled: rows > 1,
    focused: true,
  )..update(ViewportChanged(id, rows: rows, cols: 3));
  // The model refuses keys while unfocused, so it starts focused and blurs
  // after the cursor is placed.
  if (rows > 1) {
    model
      ..update(const KeyMsg('down'))
      ..update(const KeyMsg('down'))
      ..update(const KeyMsg('space'))
      ..update(const KeyMsg('down'))
      ..update(const KeyMsg('space'))
      ..update(const KeyMsg('up'))
      ..update(const KeyMsg('up'))
      ..hoverRow = 4;
  }
  model.update(const KeyMsg('right'));
  return model..focused = focused;
}

/// The rows of the state tree, in order. The `loading` node is expanded with
/// nothing cached, so it shows its indicator loading and a placeholder row.
const List<String> _treeRows = ['rest', 'cursor (unfocused)', 'hover', 'loading'];

/// Builds the state tree: the cursor on node 1, the pointer over node 2 and
/// node 3 loading its children.
TreeViewModel<String> _forcedTree(String id) {
  final model = TreeViewModel<String>(id: id, focused: true)
    ..loadRoots()
    ..applyRoots([for (final row in _treeRows) TreeNode<String>(path: '/$row', label: Line(row))])
    ..update(ViewportChanged(id, rows: _treeRows.length + 1))
    ..expand('/loading')
    ..update(const KeyMsg('down'))
    ..hoverRow = 2;
  return model..focused = false;
}

/// Builds a one-node tree that owns focus.
TreeViewModel<String> _focusedTree(String id) => TreeViewModel<String>(id: id, focused: true)
  ..loadRoots()
  ..applyRoots([TreeNode<String>(path: '/focused', label: Line('cursor (focused)'), isLeaf: true)])
  ..update(ViewportChanged(id, rows: 1));

/// Builds a focused combobox and opens its popup by pressing its toggle.
ComboboxModel<String> _openCombobox(String id) {
  final combo = ComboboxModel<String>(
    id: id,
    label: (option) => option,
    options: roles,
    placeholder: 'Select a role…',
    focused: true,
    maxVisibleRows: 4,
  );
  combo.update(
    PointerMsg(
      global: Position.origin,
      action: PointerAction.down,
      local: Position.origin,
      targetId: combo.togglePath,
    ),
  );
  return combo;
}

/// The two halves of the states page.
class StatesModel {
  /// The models drawn on the window ground.
  final StatesHalf window = StatesHalf('win.');

  /// The models drawn on the surface panel.
  final StatesHalf dialog = StatesHalf('dlg.');

  /// Whether the window half is drawn as the host of an open dialog: through
  /// `resolver.deEmphasised`, next to the unchanged surface half. The `d` key
  /// toggles it.
  bool dialogOpen = false;

  /// Scrolls both halves together. It owns the keyboard for the whole page,
  /// so it is always focused.
  final ScrollViewModel scroll = ScrollViewModel(id: 'states.scroll', focused: true);
}

/// The width of the row-label column.
const int _labelWidth = 12;

/// The states every widget row shows, in order.
const List<String> _stateRows = ['rest', 'focused', 'hover', 'pressed', 'disabled'];

/// The rows of a text input. It has no hover or pressed look, and `placeholder`
/// shows the empty field.
const List<String> _inputRows = ['rest', 'focused', 'placeholder', 'disabled'];

/// The width of a text input row's field.
const int _inputWidth = 24;

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
        child: ScrollView(
          model: model.states.scroll,
          child: Row(
            crossAxis: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _window(
                  model.states.dialogOpen ? resolver.deEmphasised : resolver,
                  model.states.window,
                  dialogOpen: model.states.dialogOpen,
                ),
              ),
              const SizedBox(width: 1),
              Expanded(child: _dialog(surface, model.states.dialog)),
            ],
          ),
        ),
      ),
      Line(
        'Each row forces one state; compare a row on the window with the same row on the surface.',
        style: resolver.ink(resolver.tones.accent),
      ),
      Line(
        'd: window as dialog host · j/k PgUp/PgDn g/G wheel: scroll',
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

/// The window half: a plain border on the frame's own ground. [r] is the
/// de-emphasised resolver while [dialogOpen], and the half then says so.
View _window(StyleResolver r, StatesHalf half, {required bool dialogOpen}) => Container(
  border: BorderType.plain,
  borderStyle: r.border(const {}),
  padding: const EdgeInsets.symmetric(horizontal: 1),
  topTitles: [Line(' Window, on background ', style: r.ink(r.tones.muted))],
  child: Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      if (dialogOpen) Line('window de-emphasised: a dialog is open', style: r.ink(r.tones.warning)),
      _sections(r, half),
    ],
  ),
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
    ..._textInputSection(r, half),
    ..._listSection(r, half),
    ..._tableSection(r, half),
    ..._treeSection(r, half),
    ..._comboboxSection(r, half),
  ],
);

List<View> _buttonSection(StyleResolver r, StatesHalf half) => _section(r, 'Button', [
  for (final state in _stateRows) _row(r, state, _hug(Button(model: half.buttons[state]!, resolver: r))),
]);

List<View> _checkboxSection(StyleResolver r, StatesHalf half) => _section(r, 'Checkbox', [
  for (final state in _stateRows) _row(r, state, _hug(Checkbox(model: half.checkboxes[state]!, resolver: r))),
]);

List<View> _radioGroupSection(StyleResolver r, StatesHalf half) => _section(r, 'RadioGroup', [
  for (final state in _stateRows) _row(r, state, _hug(RadioGroup(model: half.radioGroups[state]!, resolver: r))),
]);

List<View> _textInputSection(StyleResolver r, StatesHalf half) => _section(r, 'TextInput', [
  for (final state in _inputRows) _row(r, state, _field(TextInput(model: half.textInputs[state]!, resolver: r))),
  _row(
    r,
    'error',
    _hug(
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: _inputWidth + 2, maxW: _inputWidth + 2),
        child: Container(
          border: BorderType.plain,
          borderStyle: r.border(const {WidgetState.error}),
          child: ConstrainedBox(
            additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
            child: TextInput(model: half.errorInput, resolver: r),
          ),
        ),
      ),
    ),
  ),
]);

/// The width of the list and combobox rows.
const int _listWidth = 28;

/// The list section: the six state rows in one list, then a focused cursor
/// row in a list of its own, since only one list can own focus.
List<View> _listSection(StyleResolver r, StatesHalf half) => _section(r, 'ListView', [
  _hug(
    _box(
      height: _listRows.length,
      child: ListView<String, String>(
        model: half.cursorList,
        resolver: r,
        itemBuilder: (item, index, state) => [
          Line(item, style: index == 3 ? r.resolve(null, const {WidgetState.error}, cls: PaintClass.ink) : null),
        ],
      ),
    ),
  ),
  _hug(
    _box(
      height: 1,
      child: ListView<String, String>(
        model: half.focusedList,
        resolver: r,
        itemBuilder: (item, index, state) => [Line(item)],
      ),
    ),
  ),
]);

/// The table section: the five state rows in one table with the crosshair on,
/// then a focused cursor row in a table of its own.
List<View> _tableSection(StyleResolver r, StatesHalf half) => _section(r, 'TableView', [
  _hug(
    _box(
      height: _tableRows.length + 1,
      child: TableView(model: half.cursorTable, resolver: r, showCrosshair: true),
    ),
  ),
  _hug(
    _box(
      height: 2,
      child: TableView(model: half.focusedTable, resolver: r, showCrosshair: true),
    ),
  ),
]);

/// The tree section: the four state nodes and the loading placeholder row in
/// one tree, then a focused cursor row in a tree of its own.
List<View> _treeSection(StyleResolver r, StatesHalf half) => _section(r, 'TreeView', [
  _hug(
    _box(
      height: _treeRows.length + 1,
      child: TreeView<String>(model: half.cursorTree, resolver: r),
    ),
  ),
  _hug(
    _box(
      height: 1,
      child: TreeView<String>(model: half.focusedTree, resolver: r),
    ),
  ),
]);

/// The combobox section, last on the page. Its popup opens over the blank
/// rows below it, painted by [renderStatesPopups] after the tree. The popup
/// follows its anchor: it hides when the anchor scrolls out of view.
List<View> _comboboxSection(StyleResolver r, StatesHalf half) => [
  ..._section(r, 'Combobox', [
    _hug(_box(height: 1, child: _combobox(r, half.combobox))),
  ]),
  // Room for the popup, so scrolled to the end it opens over blank rows
  // instead of the sections above.
  const SizedBox(height: _popupRows),
];

/// The rows of a combobox popup: four options and the two border rows.
const int _popupRows = 6;

Combobox<String> _combobox(StyleResolver r, ComboboxModel<String> model) =>
    Combobox<String>(model: model, resolver: r, popupBorder: BorderType.rounded);

/// Fixes [child] to the list width and [height] rows.
View _box({required int height, required View child}) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: _listWidth, maxW: _listWidth, minH: height, maxH: height),
  child: child,
);

/// Paints the open popup of each half's combobox, over the tree that page 4
/// just rendered.
///
/// Call it after `frame.render` on page 4, with the same [resolver] the page
/// was built with. Each half's popup paints through the resolver its combobox
/// was rendered with.
void renderStatesPopups(Model model, Frame frame, StyleResolver resolver) {
  final states = model.states;
  _combobox(
    states.dialogOpen ? resolver.deEmphasised : resolver,
    states.window.combobox,
  ).renderPopup(frame);
  _combobox(resolver.on(resolver.tones.surface), states.dialog.combobox).renderPopup(frame);
}

/// Gives a text input a fixed width and one row of height, since it fills the
/// space it is given.
View _field(View input) => Row(
  children: [
    ConstrainedBox(
      additionalConstraints: const BoxConstraints(minW: _inputWidth, maxW: _inputWidth, minH: 1, maxH: 1),
      child: input,
    ),
  ],
);

/// Lets [widget] take its own width instead of the row's: a button then shows
/// its face only, and a check row shows its ground only under the text.
View _hug(View widget) => Row(children: [widget]);

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
