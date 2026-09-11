import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'contrast_page.dart';
import 'gallery_page.dart';
import 'reference_page.dart';
import 'shared.dart';

// A visual reference for the theme doctrine (docs/theming.md).
//
// The doctrine models every styled cell as a `Tone` — a color identity
// `(color, on)` — projected into paint one of three ways:
//
//   ink   fg only              (line glyphs, separators, accent text)
//   fill  fg: on, bg: color    (selected rows, button faces, badges)
//   wash  bg only              (crosshair tints under existing content)
//
// The viewer is three pages. F4 cycles them; the widget models live on one
// app model, so their state persists across pages.
//
// Page 1, reference (reference_page.dart), lays each theme out as its
// tones, grouped the way the theme itself groups them (Intent / Neutral /
// Interaction), with every tone's two halves and all three projections
// side by side. An intent strip below it shows the intent tones the way an
// app uses them — a title, a detail line, a link, and three status badges
// — since widget chrome itself paints those tones rarely (docs/theming.md,
// "Where each tone lands"). An anatomy band follows: one row per widget,
// one chip per anatomy slot, each chip painted in the style the widget
// derives when the slot is left null. A widget never adds a color of its
// own, so the chips re-color as the theme and the tier change
// (docs/theming.md, "Theming a widget"). The state strip (shared.dart's
// `stateStrip`) closes the page: the resolver's state × class matrix, one
// chip per state combination, painted over both the background and the
// surface ground with a single `resolve` call each. Page 1 is static:
// nothing on it takes focus.
//
// Page 2, gallery (gallery_page.dart), is a live gallery: the shipped
// widgets rendered under the same theme, so each tone can be watched doing
// its job. The state strip sits as a thin band above it, the same view
// page 1 uses, so the matrix and the live widgets read side by side. Tab
// and the widget keys reach the gallery only on this page. The editor
// starts with a selection, the list and the table both start with their
// first row selected under the cursor, the Dialog… button keeps an error
// face, and the checkbox group shows every look at once (checked,
// unchecked, mixed, error, disabled) — so the selection, lifted-selection,
// and error-under-focus looks all show on the first frame. The table also shows its crosshair
// from the first frame. The tree, and every table page after the first,
// load through a deliberately slow fetch, so the loading tone stays on
// screen long enough to see.
//
// Page 3, contrast (contrast_page.dart), audits contrast. Three tables —
// text on a ground, fills and composed states, and separation between two
// grounds — each row a pair painted as a swatch, its hex values, and its
// WCAG 2 contrast ratio; the first two tables grade the ratio against the
// text thresholds, the separation table does not. Every pair reads the
// theme's RGB tones through its own resolver, locked to
// `RenderPolicy.color`, since a ratio against a terminal's own ANSI-16 or
// NO_COLOR palette cannot be measured; the page's own chrome (title,
// borders) still follows F3 like the rest of the screen.
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
// MODEL
// ═══════════════════════════════════════════════════════════

/// The theme viewer's app model: every gallery widget, the theme and tier
/// state, and which of the three pages is on screen.
class Model {
  /// Creates the theme viewer's model, with the widgets that pre-seed a
  /// selection wired up so their lifted look shows on the first frame.
  Model() {
    // Select the seed's last line, so the selection tone shows immediately.
    for (var i = 0; i < seedSelection; i++) {
      editor.textArea.moveCursorLeft(isSelecting: true);
    }
    // Select the row under the cursor, so the lifted-selection look shows on
    // the first frame. The model refuses a key while unfocused, so the list
    // is focused for the toggle, then dropped back to its resting state.
    list
      ..focused = true
      ..update(const KeyMsg('space'))
      ..focused = false;
    // Select the table's first row the same way. The table's first page is
    // seeded at construction, so a row already sits under the cursor.
    table
      ..focused = true
      ..update(const KeyMsg('space'))
      ..focused = false;
    // Realize the lazily-built FocusGroup now, so the first field is focused —
    // and drawn as such, with a cursor — on the very first frame.
    focus.setIndex(0);
  }

  int themeIndex = 0;

  /// The themes the viewer cycles through.
  static const List<Theme> themes = [
    Theme.dark,
    Theme.catppuccin,
    Theme.rosePine,
    Theme.gruvbox,
    Theme.monokai,
    Theme.nord,
    Theme.tokyoNight,
    Theme.oneDark,
    Theme.dracula,
    Theme.solarized,
  ];

  Theme get theme => themes[themeIndex];

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

  /// The page on screen, 1 to 3. The app starts on the gallery.
  int page = 2;

  /// Moves to the next page, wrapping from 3 back to 1.
  void nextPage() => page = page % 3 + 1;

  /// The current page's title, as the header shows it.
  String get pageName => switch (page) {
    1 => 'Reference',
    2 => 'Gallery',
    _ => 'Contrast',
  };

  /// Theme, tier, and page keys are app-owned; they run before any widget
  /// sees the key.
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
      if (key == 'f4') {
        nextPage();
        return true;
      }
    }
    return false;
  }

  // ── the gallery widgets ──

  final name = TextInputModel(id: 'name-input', placeholder: 'Type here…');

  /// Empty means invalid here, so the error tone shows until something is
  /// typed; `update` keeps `error` in sync with the field's value.
  final requiredInput = TextInputModel(id: 'required-input', placeholder: 'Type to clear the error', error: true);

  /// A field the app disables outright, to show the disabled tone in the
  /// field chrome.
  final disabledInput = TextInputModel(id: 'disabled-input', initial: 'Not editable', disabled: true);

  final combo = ComboboxModel<String>(
    id: 'role-combo',
    label: (role) => role,
    options: roles,
    placeholder: 'Select a role…',
  );

  final editor = TextAreaModel(id: 'editor', initial: editorSeed, showLineNumbers: true);

  final okButton = ButtonModel(id: 'ok-button', label: Line(' OK '));
  final offButton = ButtonModel(id: 'off-button', label: Line(' Disabled '), disabled: true);
  final dialogButton = ButtonModel(id: 'dialog-button', label: Line(' Dialog… '));

  /// Seeded checked, so the checked mark shows on the first frame.
  final agree = CheckboxModel(
    id: 'agree-check',
    label: Line('I read the theme doctrine'),
    state: CheckState.checked,
  );

  /// A plain unchecked box, to toggle beside the checked one.
  final notify = CheckboxModel(id: 'notify-check', label: Line('Send me release notes'));

  /// Seeded mixed, so the mixed mark shows; the first toggle checks it.
  final partial = CheckboxModel(
    id: 'partial-check',
    label: Line('Some mail kinds picked'),
    state: CheckState.mixed,
  );

  /// Unchecked with the error fact set, the way a required box reads before
  /// the user accepts; the first toggle clears the error.
  final terms = CheckboxModel(id: 'terms-check', label: Line('Accept the terms (required)'), error: true);

  /// Disabled and checked: a disabled box keeps its mark, dimmed with the
  /// rest of the row.
  final locked = CheckboxModel(
    id: 'locked-check',
    label: Line('Disabled, keeps its mark'),
    state: CheckState.checked,
    disabled: true,
  );

  final list = ListViewModel<String, String>(
    items: chores,
    itemKey: (chore) => chore,
    multiSelect: true,
    isDisabled: disabledChores.contains,
  );

  final treeData = StaticTreeDataSource<void>(fileTree());
  final tree = TreeViewModel<void>();

  late final PageSource<Map<String, Object?>> source = PageSource.offset<Map<String, Object?>>(
    pageSize: 25,
    read: readRows,
  );

  late final table = TableViewModel(
    rows: tableRows(0, 25),
    totalCount: tableTotal,
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
    selectionEnabled: true,
  );

  /// Tab order of the gallery, top to bottom then left to right. The
  /// disabled button, the disabled field, and the disabled checkbox are not
  /// members: none of them can take focus.
  late final FocusGroup<Component> focus = FocusGroup<Component>(<Component>[
    name,
    requiredInput,
    combo,
    okButton,
    dialogButton,
    agree,
    notify,
    partial,
    terms,
    editor,
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
/// enough to see when a branch expands. The table's first page is seeded at
/// construction, so this only ever answers its later pages.
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

/// Runs one widget event: a load request becomes a fetch, an action event
/// becomes the status line, a modal confirm/cancel closes the dialog, and an
/// expand/collapse event needs nothing.
Cmd? onEvent(Model model, WidgetEvent event) {
  switch (event) {
    case final LoadRequest req:
      return fetchFor(model, req);
    case ButtonPressEvent(:final id) when id == model.dialogButton.id:
      model.combo.close();
      model.modal = ModalModel(id: 'demo-dialog');
    case ButtonPressEvent(:final id):
      model.status = 'Button: $id pressed';
    case CheckboxChangeEvent(:final id, :final checked):
      model.status = 'Checkbox: $id ${checked ? 'checked' : 'unchecked'}';
    case ComboboxSelectEvent():
      model.status = 'Combobox: ${model.combo.value}';
    case ListActivateEvent():
      model.status = 'List: row activated';
    case TreeActivateEvent(:final path):
      model.status = 'Tree: $path';
    case TableActivateEvent(:final action):
      model.status = 'Table: $action on row ${model.table.cursorRow + 1}';
    case ModalConfirmEvent():
      model
        ..modal = null
        ..status = 'Dialog: confirmed';
    case ModalCancelEvent():
      model
        ..modal = null
        ..status = 'Dialog: cancelled';
    case _:
      break; // expand/collapse and similar events need no app effect here
  }
  return null;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

/// Runs one message through the theme viewer.
(Model, Cmd?) update(Model model, Msg msg, UpdateContext ctx) {
  if (model.handleThemeKeys(msg)) return (model, null);

  // Kick off the tree roots once. The table's first page is already seeded
  // at construction, so only the tree needs a fetch on init.
  if (msg is InitMsg && !model.initialized) {
    model
      ..initialized = true
      // Start on the terminal's real tier, as Application probed it.
      ..policy = StyleResolver.defaultPolicy;
    return (model, Batch([fetchFor(model, model.tree.loadRoots())]));
  }

  // While the dialog is open, it owns every message addressed to it: it
  // decides whether a press outside it dismisses it, and it absorbs any key
  // it does not bind.
  if (model.modal case final modal?) {
    return switch (modal.update(msg)) {
      Handled(:final events, :final cmd) => (model, Batch([cmd, for (final e in events) onEvent(model, e)])),
      Declined() => (model, null),
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

  // Tab and the widget keys reach the router only on the gallery page; pages
  // 1 and 3 are static. Every other message still routes on every page, so a
  // fetch already in flight when the user switches pages still installs.
  final isInteraction = msg is KeyMsg || msg is PasteMsg || msg is PointerMsg;
  if (model.page == 2 || !isInteraction) {
    switch (model.router.route(msg, ctx)) {
      case Handled(:final events, :final cmd):
        // Empty means invalid here, so this keeps the required field's own
        // error fact in sync with its text on every handled interaction; the
        // required checkbox reads the same way from its own value.
        model.requiredInput.error = model.requiredInput.value.trim().isEmpty;
        model.terms.error = model.terms.state != CheckState.checked;
        return (model, Batch([cmd, for (final e in events) onEvent(model, e)]));
      case Declined():
        break; // not interaction traffic the router owns — fall through
    }
  }

  // Fallback keys — only input nothing consumed lands here.
  if (msg case KeyMsg(key: 'escape' || 'ctrl+q')) return (model, const Quit());
  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

/// Renders the theme viewer's current page under the header.
void view(Model model, Frame frame) {
  final theme = model.theme;
  final resolver = StyleResolver(theme, policy: model.policy);
  final t = resolver.tones;

  // Grounds the frame in the base tone. Under ANSI-16 this carries only a
  // foreground; under NO_COLOR it carries no color, leaving the terminal's
  // own background — what a real terminal at that tier shows.
  frame.buffer.setStyle(frame.area, resolver.ground(t.background));

  final comboView = Combobox<String>(model: model.combo, theme: theme, popupBorder: BorderType.rounded);

  final pageBody = switch (model.page) {
    1 => referencePage(theme, resolver),
    2 => Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        stateStrip(resolver),
        Expanded(child: galleryPage(model, theme, resolver, comboView)),
        Line(
          model.status.isEmpty ? 'Interact with any widget — its last command shows here' : model.status,
          style: resolver.ink(t.accent),
        ),
        Line(
          'F4 page · tab/shift+tab focus · alt+[ / alt+] (or F1/F2) theme · F3 render tier · '
          'space toggles a list row · enter activates · esc quits',
          style: resolver.ink(t.muted),
        ),
      ],
    ),
    _ => contrastPage(theme, resolver),
  };

  final ui = Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      _header(model, resolver),
      Expanded(child: pageBody),
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

  renderModalOverlay(frame, base: ui.build(), width: 46, height: 8, dialog: dialog, id: model.modal?.id);

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
          ' Theme: ${model.theme.name} · ${model.tierName} · Page ${model.page}/3: ${model.pageName}',
          style: resolver.ink(resolver.tones.primary).copyWith(addModifier: Modifier.bold),
        ),
      ),
      col(
        56,
        Align(
          alignment: Alignment.centerRight,
          child: Line(
            'F4: page  alt+[ / alt+]: theme  F3: tier  esc: quit ',
            style: resolver.ink(resolver.tones.muted),
          ),
        ),
      ),
    ],
  ),
);

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
