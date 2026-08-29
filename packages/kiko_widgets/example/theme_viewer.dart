import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// A visual reference for the theme doctrine (docs/theming.md).
//
// The doctrine models every styled cell as a `Tone` — a color identity
// `(color, on)` — projected into paint one of three ways:
//
//   ink   fg only              (line glyphs, separators, accent text)
//   fill  fg: on, bg: color    (selected rows, button faces, badges)
//   wash  bg only              (crosshair tints under existing content)
//
// The top band lays each theme out as its tones, grouped the way the theme
// itself groups them (Intent / Neutral / Interaction), with every tone's two
// halves and all three projections side by side.
//
// Between the two, an intent strip shows the intent tones the way an app
// uses them — a title, a detail line, a link, and three status badges —
// since widget chrome itself paints those tones rarely (docs/theming.md,
// "Where each tone lands").
//
// An anatomy band follows: one row per widget, one chip per anatomy slot,
// each chip painted in the style the widget derives when the slot is left
// null. A widget never adds a color of its own — every derived default is a
// projection of a theme tone — so the chips re-color as the theme and the
// tier change (docs/theming.md, "Theming a widget").
//
// The band below is a live gallery: the shipped widgets rendered under the
// same theme, so each tone can be watched doing its job. Tab moves focus
// through the gallery. The tree and table load through deliberately slow
// fetches, so the loading tone stays on screen long enough to see. The
// editor starts with a selection, so the selection tone shows on the first
// frame.
//
// Theme keys are alt+[ / alt+] with F1/F2 as a fallback: a legacy terminal
// sends alt+[ as a bare `ESC [` — the CSI introducer — so only the kitty
// keyboard protocol can deliver it as a key.
//
// F3 cycles the render tier (RGB → ANSI-16 → NO_COLOR). Every style in the
// viewer routes through resolvers built on the toggled policy, so the whole
// screen previews how the theme degrades. Under ANSI-16 the tone tables
// switch to the theme's effective `tones16` set — its own hand-authored
// table, or the derived one — and the header names which it is.

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

const _roles = ['Admin', 'Editor', 'Viewer', 'Guest', 'Owner'];

const _chores = [
  'Water the plants',
  'Answer support mail',
  'Rotate the logs',
  'Review the queue',
  'Update dependencies',
  'Back up the database',
  'Close stale tickets',
  'Refresh the certs',
  'Sweep the cache',
  'Tag the release',
  'Write the changelog',
  'Plan the sprint',
];

/// Rows the list paints as disabled, so the disabled tone shows inside data.
const _disabledChores = {2, 7};

const _editorSeed =
    'Every styled cell is a tone.\n'
    'Ink tints the glyphs.\n'
    'Fill paints on over color.\n'
    'Wash tints the ground.';

/// The length of [_editorSeed]'s last line — the span the editor pre-selects.
const _seedSelection = 22;

List<TreeNode<void>> _fileTree() => [
  TreeNode(path: '/documents', label: Line('Documents')),
  TreeNode(path: '/documents/report.pdf', label: Line('report.pdf'), isLeaf: true),
  TreeNode(path: '/documents/notes.txt', label: Line('notes.txt'), isLeaf: true),
  TreeNode(path: '/downloads', label: Line('Downloads')),
  TreeNode(path: '/downloads/image.png', label: Line('image.png'), isLeaf: true),
  TreeNode(path: '/downloads/archive.zip', label: Line('archive.zip'), isLeaf: true),
  TreeNode(path: '/music', label: Line('Music')),
  TreeNode(path: '/music/one.mp3', label: Line('one.mp3'), isLeaf: true),
  TreeNode(path: '/music/two.mp3', label: Line('two.mp3'), isLeaf: true),
];

const _tableTotal = 120;

/// A slow offset read, so scrolling the table shows its loading rows.
Future<List<Map<String, Object?>>> _readRows(int offset, int limit) async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  if (offset >= _tableTotal) return [];
  final count = (offset + limit > _tableTotal) ? _tableTotal - offset : limit;
  return List.generate(count, (i) {
    final n = offset + i + 1;
    return <String, Object?>{
      'id': 'R${n.toString().padLeft(3, '0')}',
      'name': 'Sample row $n',
      'price': 9.99 + (n % 40) * 2.5,
    };
  });
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class Model {
  Model() {
    // Select the seed's last line, so the selection tone shows immediately.
    for (var i = 0; i < _seedSelection; i++) {
      editor.textArea.moveCursorLeft(isSelecting: true);
    }
    // Realize the lazily-built FocusGroup now, so the first field is focused —
    // and drawn as such, with a cursor — on the very first frame.
    focus.setIndex(0);
  }

  int themeIndex = 0;
  static const List<Theme> themes = [Theme.dark, Theme.light, Theme.ember, Theme.ansiDark, Theme.lantern];
  static const themeNames = ['Kiko Dark', 'Kiko Light', 'Ember', 'ANSI-16 Dark', 'Lantern'];

  Theme get theme => themes[themeIndex];
  String get themeName => themeNames[themeIndex];

  void nextTheme() => themeIndex = (themeIndex + 1) % themes.length;
  void prevTheme() => themeIndex = (themeIndex - 1 + themes.length) % themes.length;

  /// The render tier every resolver in the viewer is built on. Seeded from
  /// the terminal's real policy on `InitMsg`; F3 cycles it.
  RenderPolicy policy = RenderPolicy.color;

  void nextTier() {
    policy = switch (policy) {
      RenderPolicy.color => RenderPolicy.ansi16,
      RenderPolicy.ansi16 => RenderPolicy.noColor,
      RenderPolicy.noColor => RenderPolicy.color,
    };
    // The gallery widgets build their own resolvers, which adopt the
    // process-wide default — keep it in step with the toggle.
    StyleResolver.defaultPolicy = policy;
  }

  /// The tier label for the header. Under ANSI-16 it names whether the
  /// theme brings its own `tones16` table or gets a derived one.
  String get tierName => switch (policy) {
    RenderPolicy.color => 'RGB',
    RenderPolicy.ansi16 => 'ANSI-16 (${theme.tones16 != null ? 'authored' : 'derived'})',
    RenderPolicy.noColor => 'NO_COLOR',
  };

  /// Theme and tier keys are app-owned; they run before any widget sees the
  /// key.
  bool handleThemeKeys(Msg msg) {
    if (msg case KeyMsg(:final key)) {
      if (key == 'alt+[' || key == 'f1') {
        prevTheme();
        return true;
      }
      if (key == 'alt+]' || key == 'f2') {
        nextTheme();
        return true;
      }
      if (key == 'f3') {
        nextTier();
        return true;
      }
    }
    return false;
  }

  // ── the gallery widgets ──

  final name = TextInputModel(id: 'name-input', placeholder: 'Type here…');

  /// Empty means invalid here, so the error tone shows until something is typed.
  final requiredInput = TextInputModel(id: 'required-input', placeholder: 'Type to clear the error');

  bool get requiredMissing => requiredInput.value.trim().isEmpty;

  final combo = ComboboxModel<String>(
    id: 'role-combo',
    label: (role) => role,
    options: _roles,
    placeholder: 'Select a role…',
  );

  final editor = TextAreaModel(id: 'editor', initial: _editorSeed, showLineNumbers: true);

  final okButton = ButtonModel(id: 'ok-button', label: Line(' OK '));
  final offButton = ButtonModel(id: 'off-button', label: Line(' Disabled '), disabled: true);
  final dialogButton = ButtonModel(id: 'dialog-button', label: Line(' Dialog… '));

  final list = ListViewModel<String, String>(
    items: _chores,
    itemKey: (chore) => chore,
    multiSelect: true,
    isDisabled: _disabledChores.contains,
  );

  final treeData = StaticTreeDataSource<void>(_fileTree());
  final tree = TreeViewModel<void>();

  late final PageSource<Map<String, Object?>> source = PageSource.offset<Map<String, Object?>>(
    pageSize: 25,
    read: _readRows,
  );

  late final table = TableViewModel(
    pageSize: source.pageSize,
    keyField: 'id',
    columns: [
      TableColumn(field: 'id', label: Line('ID'), width: 6),
      TableColumn(field: 'name', label: Line('Name'), width: 16),
      TableColumn(
        field: 'price',
        label: Line('Price'),
        width: 8,
        alignment: TextAlign.end,
        render: (ctx) => Line('\$${(ctx.value as double? ?? 0).toStringAsFixed(2)}'),
      ),
    ],
    loadThreshold: 8,
    loadingIndicator: Line('Loading…'),
    emptyPlaceholder: Line('No rows'),
  );

  /// Tab order of the gallery. The disabled button and the disabled field
  /// mock are not members: neither can take focus.
  late final FocusGroup<Component> focus = FocusGroup<Component>(<Component>[
    name,
    requiredInput,
    combo,
    editor,
    okButton,
    dialogButton,
    list,
    tree,
    table,
  ]);

  late final FocusRouter router = FocusRouter(focus);

  /// The open dialog, or null. The app owns whether a modal is open.
  ModalModel? modal;

  /// The last command a gallery widget sent — the status line shows it.
  String status = '';

  bool initialized = false;
}

// ═══════════════════════════════════════════════════════════
// LOAD PLUMBING
// ═══════════════════════════════════════════════════════════

/// Answers a widget's [LoadRequest]; the tree and the table both resolve here.
///
/// The tree's delay is deliberate: it keeps the loading tone on screen long
/// enough to see when a branch expands.
Cmd fetchFor(Model model, LoadRequest req) {
  if (req.id == model.tree.id) {
    final key = req.key;
    return Task<List<TreeNode<void>>>(
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        return switch (key) {
          RootsKey() => model.treeData.getRoots(),
          PathKey(:final path) => model.treeData.getChildren(path),
          _ => Future.value(const <TreeNode<void>>[]),
        };
      },
      onSuccess: (data) => LoadResult<List<TreeNode<void>>>(req.id, key: key, data: data),
      onError: (e) => LoadResult<List<TreeNode<void>>>(req.id, key: key, error: e),
    );
  }
  if (req.id == model.table.id) return fetchInto(req, model.source);
  return declineLoad(req, error: 'no source wired for ${req.id}');
}

/// Runs whatever a widget returned: load requests become fetches, action
/// commands become the status line, expand/collapse events need nothing.
Cmd? handleCmds(Model model, Cmd? cmd) {
  final cmds = switch (cmd) {
    null => const <Cmd>[],
    Batch(:final cmds) => cmds,
    _ => [cmd],
  };
  final fetches = <Cmd>[];
  for (final c in cmds) {
    switch (c) {
      case final LoadRequest req:
        fetches.add(fetchFor(model, req));
      case ButtonPressCmd(:final id) when id == model.dialogButton.id:
        model.combo.close();
        model.modal = ModalModel(id: 'demo-dialog');
      case ButtonPressCmd(:final id):
        model.status = 'Button: $id pressed';
      case ComboboxSelectCmd():
        model.status = 'Combobox: ${model.combo.value}';
      case ListActionCmd():
        model.status = 'List: row activated';
      case TreeActionCmd(:final path):
        model.status = 'Tree: $path';
      case TableActionCmd(:final action):
        model.status = 'Table: $action on row ${model.table.cursorRow + 1}';
      case _:
        break; // expand/collapse and similar events need no app effect here
    }
  }
  return switch (fetches.length) {
    0 => null,
    1 => fetches.first,
    _ => Batch(fetches),
  };
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(Model, Cmd?) update(Model model, Msg msg, UpdateContext ctx) {
  if (model.handleThemeKeys(msg)) return (model, null);

  // Kick off the tree roots and the table's first page once. The app owns the
  // table's data, so it asserts the total count directly.
  if (msg is InitMsg && !model.initialized) {
    model
      ..initialized = true
      // Start on the terminal's real tier, as Application probed it.
      ..policy = StyleResolver.defaultPolicy
      ..table.totalCount = _tableTotal;
    return (
      model,
      Batch([
        fetchFor(model, model.tree.loadRoots()),
        fetchFor(model, model.table.loadFirstPage()),
      ]),
    );
  }

  // While the dialog is open it captures all input. A down-press outside its
  // rendered rect dismisses it — the same ModalCancelCmd Escape emits.
  if (model.modal case final modal?) {
    if (msg case final PointerMsg pointer when pointer.isDown) {
      final rect = ctx.hits.rectOf(modal.id);
      if (rect == null || !rect.contains(pointer.global)) {
        return switch (modal.dismiss()) {
          ModalCancelCmd() => (
            model
              ..modal = null
              ..status = 'Dialog: cancelled',
            null,
          ),
          _ => (model, null),
        };
      }
    }
    return switch (modal.update(msg)) {
      Handled(cmd: ModalConfirmCmd()) => (
        model
          ..modal = null
          ..status = 'Dialog: confirmed',
        null,
      ),
      Handled(cmd: ModalCancelCmd()) => (
        model
          ..modal = null
          ..status = 'Dialog: cancelled',
        null,
      ),
      _ => (model, null),
    };
  }

  // A press outside the combobox's own scope closes its popup. The message
  // keeps going: this never swallows the press.
  if (msg case final PointerMsg pointer when pointer.isDown) {
    final target = pointer.targetId;
    if (target == null || HitTag.resolve(target, {model.combo.id}) == null) {
      model.combo.close();
    }
  }

  // The one routing line: keys to the focused widget (tab/shift+tab reserved
  // for traversal), a pointer to the widget it is addressed to — moving focus
  // there on a down-press — and a load result to the widget whose id it
  // carries, which installs it.
  switch (model.router.route(msg, ctx)) {
    case Handled(:final cmd):
      return (model, handleCmds(model, cmd));
    case Declined():
      break; // not interaction traffic the router owns — fall through
  }

  // Fallback keys — only input nothing consumed lands here.
  if (msg case KeyMsg(key: 'escape' || 'ctrl+q')) return (model, const Quit());
  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void view(Model model, Frame frame) {
  final theme = model.theme;
  final resolver = StyleResolver(theme, policy: model.policy);
  final t = resolver.tones;

  // Grounds the frame in the base tone. Under ANSI-16 this carries only a
  // foreground; under NO_COLOR it carries no color, leaving the terminal's
  // own background — what a real terminal at that tier shows.
  frame.buffer.setStyle(frame.area, resolver.ground(t.background));

  final comboView = Combobox<String>(model: model.combo, theme: theme, popupBorder: BorderType.rounded);

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      _header(model, resolver),
      // The tone tables keep their natural height; the gallery gets the rest.
      // They read the resolver's effective set, so under ANSI-16 they show
      // the theme's tones16 table instead of its RGB tones.
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minH: 9, maxH: 9),
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _toneSection(resolver, 'Intent', _intent(t))),
            Expanded(child: _toneSection(resolver, 'Neutral', _neutral(t))),
            Expanded(
              child: _toneSection(
                resolver,
                'Interaction${theme.derivesCursor || theme.derivesHover ? '  * derived' : ''}',
                _interaction(t, theme),
              ),
            ),
          ],
        ),
      ),
      _intentStrip(resolver),
      _anatomyBand(resolver),
      Expanded(
        child: Row(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            _formColumn(model, theme, resolver, comboView),
            Expanded(child: _pane(resolver, 'ListView', model.list.focused, _listView(model, theme))),
            Expanded(
              child: _pane(resolver, 'TreeView', model.tree.focused, TreeView(model: model.tree, theme: theme)),
            ),
            Expanded(
              child: _pane(resolver, 'TableView', model.table.focused, TableView(model: model.table, theme: theme)),
            ),
          ],
        ),
      ),
      Line(
        model.status.isEmpty ? 'Interact with any widget — its last command shows here' : model.status,
        style: resolver.ink(t.accent),
      ),
      Line(
        'tab/shift+tab focus · alt+[ / alt+] (or F1/F2) theme · F3 render tier · space toggles a list row · '
        'enter activates · esc quits',
        style: resolver.ink(t.muted),
      ),
    ],
  );

  final dialog = switch (model.modal) {
    final modal? => modalDialog(
      id: modal.id,
      theme: theme,
      topTitles: [Line(' Dialog ', style: resolver.ink(t.focus))],
      content: Column(
        mainAxis: MainAxisAlignment.center,
        children: [
          Center(child: Line('This dialog sits on the surface tone.')),
          const SizedBox(height: 1),
          Center(child: Line('[Enter] confirm   [Esc]/outside cancel', style: resolver.ink(t.muted))),
        ],
      ).build(),
    ),
    null => null,
  };

  renderModalOverlay(frame, base: ui.build(), width: 46, height: 8, dialog: dialog);

  // Second pass: the popup paints over the tree that just rendered. A no-op
  // while the combobox is closed.
  comboView.renderPopup(frame);
}

View _header(Model model, StyleResolver resolver) => Container(
  border: BorderType.plain,
  borderStyle: resolver.border(const {}),
  child: Row(
    children: [
      Expanded(
        child: Line(
          ' Theme: ${model.themeName} · ${model.tierName}',
          style: resolver.ink(resolver.tones.primary).copyWith(addModifier: Modifier.bold),
        ),
      ),
      _col(
        46,
        Align(
          alignment: Alignment.centerRight,
          child: Line('alt+[ / alt+]: theme  F3: tier  esc: quit ', style: resolver.ink(resolver.tones.muted)),
        ),
      ),
    ],
  ),
);

/// The intent tones as app content: one piece per tone, ink for text and
/// fill for badges. Widget chrome paints these tones rarely, so this strip
/// is where a change to them shows. Every piece projects through the
/// resolver, so the strip degrades with the tier like the rest of the
/// screen.
View _intentStrip(StyleResolver resolver) {
  final t = resolver.tones;
  return Container(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: [Line(' Intent in use — the app’s vocabulary ', style: resolver.ink(t.secondary))],
    child: Row(
      children: [
        Line('Deploy report', style: resolver.ink(t.primary).copyWith(addModifier: Modifier.bold)),
        const SizedBox(width: 3),
        Line('3 services checked', style: resolver.ink(t.secondary)),
        const SizedBox(width: 3),
        Line('view the log', style: resolver.ink(t.accent)),
        const SizedBox(width: 4),
        Line(' ✓ Saved ', style: resolver.fill(t.success)),
        const SizedBox(width: 2),
        Line(' ⚠ Low disk ', style: resolver.fill(t.warning)),
        const SizedBox(width: 2),
        Line(' ✗ 2 errors ', style: resolver.fill(t.error)),
      ],
    ),
  );
}

// ── the anatomy band ──

/// The anatomy band: one row per widget, one chip per anatomy slot.
///
/// Each chip is the slot's name painted in the style the widget derives for
/// that slot when it is left `null` — every default a projection of a theme
/// tone, since a widget never adds a color of its own. A bracketed chip
/// (`[item]`, `[row]`, `[obscured]`) marks a slot with no derived default:
/// it inherits whatever the surrounding pane paints. Wash chips keep the
/// default text over their tint, the way a wash lands on content.
View _anatomyBand(StyleResolver resolver) {
  final t = resolver.tones;
  final text = resolver.ink(Tone(color: t.background.on));
  final mutedInk = resolver.ink(t.muted);
  final selectedFill = resolver.resolve(null, const {WidgetState.selected});
  final cursorFill = resolver.resolve(null, const {WidgetState.cursor});
  final cursorWash = text.patch(resolver.resolve(null, const {WidgetState.cursor}, cls: PaintClass.wash));

  final rows = <(String, List<(String, Style)>)>[
    (
      'TextInput',
      [
        ('placeholder', mutedInk),
        ('fill', mutedInk),
        ('[obscured]', text),
      ],
    ),
    (
      'TextArea',
      [
        ('placeholder', mutedInk),
        ('selection', resolver.fill(t.selection)),
        ('lineNumber', mutedInk),
      ],
    ),
    (
      'Combobox',
      [
        ('[toggle]', text),
        ('popupGround', resolver.ground(t.surface)),
        ('loadingRow', mutedInk),
        ('errorRow', mutedInk),
        ('stalledRow', mutedInk),
      ],
    ),
    (
      'ListView',
      [
        ('[item]', text),
        ('selectedItem', selectedFill),
        ('cursorItem', cursorFill),
        ('loadingItem', mutedInk),
        ('placeholder', mutedInk),
      ],
    ),
    (
      'TreeView',
      [
        ('[item]', text),
        ('cursorItem', cursorFill),
        ('placeholder', mutedInk),
      ],
    ),
    (
      'TableView',
      [
        ('[header]', text.copyWith(addModifier: Modifier.bold)),
        ('[row]', text),
        ('separator', resolver.ink(t.border)),
        ('selectedRow', selectedFill),
        ('cursorRow', cursorWash),
        ('cursorColumn', cursorWash),
        ('cursorCell', cursorFill),
        ('loadingRow', mutedInk),
        ('placeholder', mutedInk),
      ],
    ),
  ];

  return Container(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: [
      Line(' Anatomy — widget style slots; a null slot derives from a theme tone ', style: resolver.ink(t.secondary)),
    ],
    child: Column(
      children: [
        for (final (name, slots) in rows) _anatomyRow(resolver, name, slots),
        // Button publishes no anatomy class: its resting face is the primary
        // fill and every other look rides the state matrix.
        Row(
          children: [
            _col(11, Line('Button', style: mutedInk)),
            Line(' primary.fill face ', style: resolver.fill(t.primary)),
            const SizedBox(width: 1),
            Line('no slots — states ride the matrix', style: mutedInk),
          ],
        ),
      ],
    ),
  );
}

/// One anatomy row: the widget's name, then its slots as painted chips.
View _anatomyRow(StyleResolver resolver, String name, List<(String, Style)> slots) => Row(
  children: [
    _col(11, Line(name, style: resolver.ink(resolver.tones.muted))),
    for (final (slot, style) in slots) ...[
      Line(' $slot ', style: style),
      const SizedBox(width: 1),
    ],
  ],
);

// ── the gallery ──

/// The form column: text inputs in three states, the combobox, the editor,
/// and the button row.
View _formColumn(Model model, Theme theme, StyleResolver resolver, View comboView) {
  final requiredStates = {
    if (model.requiredInput.focused) WidgetState.focused,
    if (model.requiredMissing) WidgetState.error,
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
        // TextInput has no disabled mode; the disabled tone is shown by the
        // field chrome and a read-only line. Not a focus member.
        _field(
          resolver,
          'TextInput — disabled',
          const {WidgetState.disabled},
          Line('Not editable', style: resolver.resolve(null, const {WidgetState.disabled}, cls: PaintClass.ink)),
        ),
        _field(resolver, 'Combobox', {if (model.combo.focused) WidgetState.focused}, comboView),
        Expanded(
          child: Container(
            border: BorderType.plain,
            borderStyle: resolver.border({if (model.editor.focused) WidgetState.focused}),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            topTitles: [
              Line(' TextArea ', style: _titleInk(resolver, {if (model.editor.focused) WidgetState.focused})),
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
            Button(model: model.dialogButton, theme: theme),
          ],
        ),
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
  topTitles: [Line(' $title ', style: _titleInk(resolver, states))],
  child: ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 1, maxH: 1),
    child: child,
  ),
);

/// Title ink for a section: resting muted ink, with the matrix's state
/// contributions (error, focus, disabled) patched over it.
Style _titleInk(StyleResolver resolver, Set<WidgetState> states) =>
    resolver.resolve(resolver.ink(resolver.tones.muted), states, cls: PaintClass.ink);

/// A bordered gallery pane; the border and the title show the focus state.
View _pane(StyleResolver resolver, String title, bool focused, View child) => Container(
  border: BorderType.plain,
  borderStyle: resolver.border({if (focused) WidgetState.focused}),
  topTitles: [
    Line(' $title ', style: _titleInk(resolver, {if (focused) WidgetState.focused})),
  ],
  child: child,
);

View _listView(Model model, Theme theme) => ListView(
  model: model.list,
  theme: theme,
  itemBuilder: (chore, index, state) => [
    Line(' ${state.checked ? '●' : '○'} $chore'),
  ],
);

// ── the tone tables ──

// The doctrine's tone groups, in the doctrine's order. They read a ToneSet
// — the resolver's effective set — so under ANSI-16 the rows show the
// theme's tones16 table.

List<(String, Tone)> _intent(ToneSet t) => [
  ('primary', t.primary),
  ('secondary', t.secondary),
  ('accent', t.accent),
  ('error', t.error),
  ('warning', t.warning),
  ('success', t.success),
];

List<(String, Tone)> _neutral(ToneSet t) => [
  ('background', t.background),
  ('surface', t.surface),
  ('border', t.border),
  ('muted', t.muted),
  ('disabled', t.disabled),
];

/// `hover` is not part of [ToneSet] (a wash-only tone has no ANSI-16 slot),
/// so its row always reads the theme. A `*` marks a tone the theme derives
/// from its background instead of setting explicitly.
List<(String, Tone)> _interaction(ToneSet t, Theme theme) => [
  ('focus', t.focus),
  ('selection', t.selection),
  ('cursor${theme.derivesCursor ? ' *' : ''}', t.cursor),
  ('hover${theme.derivesHover ? ' *' : ''}', theme.hover),
];

View _toneSection(StyleResolver resolver, String title, List<(String, Tone)> tones) {
  final rows = <View>[_headerRow(resolver)];
  for (final (name, tone) in tones) {
    rows.add(_toneRow(resolver, name, tone));
  }
  return Container(
    border: BorderType.plain,
    borderStyle: resolver.border(const {}),
    padding: const EdgeInsets.symmetric(horizontal: 1),
    topTitles: [Line(title, style: resolver.ink(resolver.tones.secondary))],
    child: Column(children: rows),
  );
}

View _headerRow(StyleResolver resolver) {
  final label = resolver.ink(resolver.tones.muted);
  return Row(
    children: [
      _col(11, Line('Tone', style: label)),
      _col(8, Line('color', style: label)),
      _col(8, Line('on', style: label)),
      _col(4, Line('ink', style: label)),
      const SizedBox(width: 1),
      _col(4, Line('fill', style: label)),
      const SizedBox(width: 1),
      _col(4, Line('wash', style: label)),
    ],
  );
}

/// One tone: its name, its two halves as labels, then its three projections
/// — all through the resolver, so the row degrades with the render tier.
View _toneRow(StyleResolver resolver, String name, Tone tone) {
  final muted = resolver.ink(resolver.tones.muted);
  final defaultText = resolver.ink(Tone(color: resolver.tones.background.on));
  return Row(
    children: [
      // Name, in the effective set's default text color.
      _col(11, Line(name, style: defaultText)),
      // color half — drawn in its own hue (its ink) so the swatch reads true.
      _col(8, Line(_colorLabel(tone.color), style: tone.color != null ? resolver.ink(tone) : muted)),
      // on half — drawn in the on color, or muted "—" when the tone has none.
      _col(8, Line(_colorLabel(tone.on), style: tone.on != null ? resolver.ink(Tone(color: tone.on)) : muted)),
      // ink: fg only — tinted text over the theme background.
      _swatch(4, resolver.ink(tone)),
      const SizedBox(width: 1),
      // fill: on over color.
      _swatch(4, resolver.fill(tone)),
      const SizedBox(width: 1),
      // wash: bg only — default text sitting on the tint.
      _swatch(4, defaultText.patch(resolver.wash(tone))),
    ],
  );
}

/// Pins [child] to an exact [width], one visual row tall.
View _col(int width, View child) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: width, maxW: width),
  child: child,
);

/// A projection swatch: `Ab` painted in [style], padded to [width] cells.
View _swatch(int width, Style style) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: width, maxW: width),
  child: Container(
    ground: style,
    child: Line(' Ab ', style: style),
  ),
);

/// Short names for the sixteen ANSI slots; a `+` marks a bright variant.
const _ansiNames = [
  'black',
  'red',
  'green',
  'yellow',
  'blue',
  'magenta',
  'cyan',
  'gray',
  'darkGray',
  'red+',
  'green+',
  'yellow+',
  'blue+',
  'magenta+',
  'cyan+',
  'white',
];

/// A tone half as text: an ANSI-16 name, hex for RGB, an em dash when unset.
String _colorLabel(Color? color) {
  if (color == null) return '—';
  if (color == Color.reset) return 'reset';
  if (color.kind == ColorKind.ansi) return _ansiNames[color.value];

  final rgb = color.toRgb();
  return '#${rgb.value.toRadixString(16).padLeft(6, '0')}';
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Theme Viewer', mouseEvents: true).run(
      init: Model(),
      update: update,
      view: view,
    ),
  );
}
