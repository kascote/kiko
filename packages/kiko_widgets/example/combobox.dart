// Two comboboxes: one over an in-memory list, one over a remote search.
//
// Shows:
// - The in-memory path: options: seeds the popup, typed text filters it
//   client-side (ComboboxModel.matches).
// - The remote path: options omitted, so the model asks the app for every
//   query through a Loadable LoadRequest/LoadResult exchange, keyed by
//   QueryKey. The app answers with data, an error (typing "err" into the
//   search), or declineLoad (F3 pauses the search to demonstrate a refusal).
// - The app-side outside-press dismissal recipe: a press whose targetId
//   resolves to neither combobox's own scope closes both, before the press
//   routes normally.
// - The two-pass render: the base tree renders first, then renderPopup
//   paints whichever combobox is open, over what already painted.
// - clear() is app-driven: ctrl+r clears whichever combobox holds focus. The
//   combobox itself binds no key to it.

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

const _roles = ['Admin', 'Editor', 'Viewer', 'Guest', 'Owner'];

/// A simulated user directory: a name search with a slow round trip.
///
/// This is app code — the shape a real search endpoint has. Kiko only sees
/// it through the LoadRequest/LoadResult exchange in [fetchFor].
class UserDirectory {
  static const _names = [
    'Ada Lovelace',
    'Grace Hopper',
    'Alan Turing',
    'Barbara Liskov',
    'Margaret Hamilton',
    'Katherine Johnson',
    'Edsger Dijkstra',
    'Radia Perlman',
    'Donald Knuth',
    'Frances Allen',
  ];

  /// The names matching [query], after a simulated network delay.
  ///
  /// Throws when [query] contains "err", so the example has a repeatable way
  /// to trigger the error path from the keyboard.
  Future<List<String>> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (query.toLowerCase().contains('err')) throw StateError('search backend unavailable');
    if (query.isEmpty) return _names;
    return _names.where((name) => name.toLowerCase().contains(query.toLowerCase())).toList();
  }
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  AppModel() {
    focus.setIndex(0);
  }

  final directory = UserDirectory();

  /// In-memory options: the popup filters [_roles] client-side as the field
  /// is edited.
  final roleCombo = ComboboxModel<String>(
    id: 'role-combo',
    label: (role) => role,
    options: _roles,
    placeholder: 'Select a role...',
  );

  /// Remote options: `options` is omitted, so every query goes to the app
  /// through [Loadable.applyLoad] — see [fetchFor].
  final userCombo = ComboboxModel<String>(
    id: 'user-combo',
    label: (name) => name,
    placeholder: 'Search a user...',
  );

  /// While true, [fetchFor] refuses every query with `declineLoad` instead of
  /// searching — a policy refusal, toggled by F3, with nothing failed and no
  /// error to show.
  bool searchPaused = false;

  late final FocusGroup<Component> focus = FocusGroup([roleCombo, userCombo]);

  /// The one routing line the app writes: pointers by whichever combobox's
  /// scope they land in, keys to the focused one, focus to whatever a press
  /// lands on.
  late final FocusRouter router = FocusRouter(focus);

  String status = '';
}

// ═══════════════════════════════════════════════════════════
// LOAD PLUMBING
// ═══════════════════════════════════════════════════════════

/// Answers the user combobox's [LoadRequest]: data, an error, or a refusal.
///
/// A combobox names its load by [QueryKey], not a page, so this is a plain
/// hand-rolled [Task] rather than `fetchInto` (which expects a `PageSource`).
Cmd fetchFor(AppModel model, LoadRequest req) {
  if (req.id != model.userCombo.id) return declineLoad(req, error: 'no source wired for ${req.id}');
  if (model.searchPaused) return declineLoad(req); // policy — nothing failed, nothing to show

  final key = req.key;
  if (key is! QueryKey) return declineLoad(req, error: 'unexpected key $key');

  return Task(
    () => model.directory.search(key.query),
    onSuccess: (data) => LoadResult<List<String>>(req.id, key: key, data: data),
    onError: (e) => LoadResult<List<String>>(req.id, key: key, error: e),
  );
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

/// Whether [targetId] resolves to neither combobox's own scope — a
/// background press, or one landing on chrome neither combobox owns.
bool _outsideBothCombos(String? targetId, AppModel model) =>
    targetId == null || HitTag.resolve(targetId, {model.roleCombo.id, model.userCombo.id}) == null;

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext ctx) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // A remote query's answer routes home by id; applyLoad installs it or
  // records the failure, and the popup's status row reads it back.
  if (msg case final LoadResult<Object?> r) {
    if (r.id == model.userCombo.id) model.userCombo.applyLoad(r);
    return (model, null);
  }

  // A press outside every combobox's own scope closes whichever one is
  // open. The message keeps going: this only closes the popup, it never
  // swallows the press.
  if (msg case final PointerMsg pointer when pointer.isDown && _outsideBothCombos(pointer.targetId, model)) {
    model.roleCombo.close();
    model.userCombo.close();
  }

  switch (model.router.route(msg, ctx)) {
    case Handled(cmd: ComboboxSelectCmd(:final id)):
      model.status = id == model.roleCombo.id ? 'Role: ${model.roleCombo.value}' : 'User: ${model.userCombo.value}';
      return (model, null);
    case Handled(cmd: final LoadRequest req):
      return (model, fetchFor(model, req));
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic the router owns — fall through
  }

  if (msg case KeyMsg(:final key)) {
    // App-driven clear: the combobox binds no key to it itself.
    if (key == 'ctrl+r') {
      if (model.focus.focused case final ComboboxModel<String> combo) combo.clear();
      return (model, null);
    }
    if (key == 'f3') {
      model.searchPaused = !model.searchPaused;
      return (model, null);
    }
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
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.color));

  final roleView = Combobox<String>(model: model.roleCombo, theme: theme);
  final userView = Combobox<String>(
    model: model.userCombo,
    theme: theme,
    loadingLabel: 'Searching…',
    errorLabel: 'Search failed',
  );

  final helpLine = model.searchPaused
      ? 'Search paused — F3 resumes it'
      : 'tab switch · type/↓ open · ↑↓ nav · enter select · ctrl+r clear · '
            'F3 pause search · esc/click outside close · F1/F2 theme · ctrl+q quit';

  final ui = Container(
    topTitles: [Line('Combobox Demo', style: theme.muted.ink)],
    padding: const EdgeInsets.all(1),
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Line('Role — in-memory options', style: theme.muted.ink),
        ConstrainedBox(additionalConstraints: const BoxConstraints(minH: 1, maxH: 1), child: roleView),
        const SizedBox(height: 1),
        Line('User — remote search (try "err" for a failure)', style: theme.muted.ink),
        ConstrainedBox(additionalConstraints: const BoxConstraints(minH: 1, maxH: 1), child: userView),
        const Expanded(child: SizedBox()),
        Line(model.status.isEmpty ? 'Nothing selected yet' : model.status, style: Style(fg: theme.accent.color)),
        Line(helpLine, style: theme.muted.ink),
      ],
    ),
  );

  frame.render(ui);

  // Second pass: whichever combobox is open paints its popup over the tree
  // that just rendered. Each call is a no-op while its own model is closed.
  roleView.renderPopup(frame);
  userView.renderPopup(frame);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Combobox Demo', mouseEvents: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
