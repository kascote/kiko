// Three comboboxes: one over an in-memory list, one over a remote search,
// and one chromed, with custom popup rows.
//
// Shows:
// - The in-memory path: options: seeds the popup, typed text filters it
//   client-side (ComboboxModel.matches).
// - The remote path: options omitted, so the model asks the app for every
//   query with a LoadRequest keyed by QueryKey. The app answers with data, an
//   error (typing "err" into the search), or declineLoad (F3 pauses the
//   search to demonstrate a refusal: the popup shows the stalled row, here
//   'Search paused'). The answer is a LoadResult carrying the combobox's id;
//   the router delivers it and the combobox installs it. The app never
//   routes a result by hand.
// - Custom popup rows: itemBuilder paints each country's name at the left
//   edge of the row and its flag at the right.
// - Chrome: the country field sits in a bordered Container the app owns,
//   and popupBorder frames the popup to match.
// - The app-side outside-press dismissal recipe: a press whose targetId
//   resolves to no combobox's own scope closes all three, before the press
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

/// The width every combobox row gets — the demo keeps them narrow rather
/// than stretched across the terminal.
const _comboWidth = 36;

/// The country popup's row width: [_comboWidth] minus the field chrome's
/// border and padding (two cells each) and the popup's own border (two).
const int _countryRowWidth = _comboWidth - 6;

const _roles = ['Admin', 'Editor', 'Viewer', 'Guest', 'Owner'];

/// One selectable country: the name the field shows and filters on, and the
/// flag the popup row right-aligns.
typedef Country = ({String name, String flag});

const _countries = <Country>[
  (name: 'Argentina', flag: '🇦🇷'),
  (name: 'Bolivia', flag: '🇧🇴'),
  (name: 'Brazil', flag: '🇧🇷'),
  (name: 'Chile', flag: '🇨🇱'),
  (name: 'Colombia', flag: '🇨🇴'),
  (name: 'Ecuador', flag: '🇪🇨'),
  (name: 'Mexico', flag: '🇲🇽'),
  (name: 'Paraguay', flag: '🇵🇾'),
  (name: 'Peru', flag: '🇵🇪'),
  (name: 'Uruguay', flag: '🇺🇾'),
  (name: 'Venezuela', flag: '🇻🇪'),
];

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

  /// Remote options: `options` is omitted, so every query goes to the app as
  /// a [LoadRequest] — see [fetchFor] — and its answer comes back to the
  /// combobox through the router.
  final userCombo = ComboboxModel<String>(
    id: 'user-combo',
    label: (name) => name,
    placeholder: 'Search a user...',
  );

  /// In-memory options rendered through a custom item builder: the country
  /// name at the left edge of the popup row, its flag at the right.
  final countryCombo = ComboboxModel<Country>(
    id: 'country-combo',
    label: (country) => country.name,
    options: _countries,
    placeholder: 'Select a country...',
  );

  /// While true, [fetchFor] refuses every query with `declineLoad` instead of
  /// searching — a policy refusal, toggled by F3, with nothing failed and no
  /// error to show.
  bool searchPaused = false;

  /// Every combobox, for the recipes that act on all of them at once.
  late final List<ComboboxModel<Object?>> combos = [roleCombo, userCombo, countryCombo];

  late final FocusGroup<Component> focus = FocusGroup([roleCombo, userCombo, countryCombo]);

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

/// Whether [targetId] resolves to no combobox's own scope — a background
/// press, or one landing on chrome no combobox owns (the country field's
/// border included).
bool _outsideEveryCombo(String? targetId, AppModel model) =>
    targetId == null || HitTag.resolve(targetId, {for (final combo in model.combos) combo.id}) == null;

/// The status line for a commit on the combobox with [id].
String _selectionStatus(AppModel model, String id) {
  if (id == model.roleCombo.id) return 'Role: ${model.roleCombo.value}';
  if (id == model.userCombo.id) return 'User: ${model.userCombo.value}';
  final country = model.countryCombo.value;
  return country == null ? '' : 'Country: ${country.name} ${country.flag}';
}

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext ctx) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // A press outside every combobox's own scope closes whichever one is
  // open. The message keeps going: this only closes the popup, it never
  // swallows the press.
  if (msg case final PointerMsg pointer when pointer.isDown && _outsideEveryCombo(pointer.targetId, model)) {
    for (final combo in model.combos) {
      combo.close();
    }
  }

  switch (model.router.route(msg, ctx)) {
    case Handled(cmd: ComboboxSelectCmd(:final id)):
      model.status = _selectionStatus(model, id);
      return (model, null);
    case Handled(cmd: final LoadRequest req):
      return (model, fetchFor(model, req));
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic the router owns — fall through
  }

  if (msg case KeyMsg(:final key)) {
    // App-driven clear: the combobox binds no key to it itself. A remote
    // clear() while open re-asks the empty query; run it like any other.
    if (key == 'ctrl+r') {
      if (model.focus.focused case final ComboboxModel<Object?> combo) {
        if (combo.clear() case final LoadRequest req) return (model, fetchFor(model, req));
      }
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

/// One country popup row: the name at the left edge, the flag right-aligned
/// at the row's end. A flag emoji paints two cells wide.
List<Line> _countryRow(Country country, int index, ItemState state) {
  final pad = (_countryRowWidth - country.name.length - 2).clamp(1, _countryRowWidth);
  return [Line('${country.name}${' ' * pad}${country.flag}')];
}

/// Bounds [combo] to one row — a combobox fills whatever box it is given,
/// like a bare TextInput — and, when [width] is given, to that width.
View _comboRow(View combo, {int? width}) => ConstrainedBox(
  additionalConstraints: BoxConstraints(minW: width ?? 0, maxW: width, minH: 1, maxH: 1),
  child: combo,
);

void appView(AppModel model, Frame frame) {
  final theme = model.theme;
  final resolver = StyleResolver(theme);
  final t = resolver.tones;
  frame.buffer.setStyle(frame.area, resolver.ground(resolver.tones.background));

  final roleView = Combobox<String>(model: model.roleCombo, theme: theme);
  final userView = Combobox<String>(
    model: model.userCombo,
    theme: theme,
    loadingLabel: Line('Searching…'),
    errorLabel: Line('Search failed'),
    stalledLabel: Line('Search paused'),
  );
  final countryView = Combobox<Country>(
    model: model.countryCombo,
    theme: theme,
    itemBuilder: _countryRow,
    popupBorder: BorderType.rounded,
  );

  final helpLine = model.searchPaused
      ? 'Search paused — F3 resumes it'
      : 'tab switch · type/↓ open · ↑↓ nav · enter select · ctrl+r clear · '
            'F3 pause search · esc/click outside close · F1/F2 theme · ctrl+q quit';

  final ui = Container(
    topTitles: [Line('Combobox Demo', style: resolver.ink(t.muted))],
    padding: const EdgeInsets.all(1),
    child: Column(
      children: [
        Line('Role — in-memory options', style: resolver.ink(t.muted)),
        _comboRow(roleView, width: _comboWidth),
        const SizedBox(height: 1),
        Line('User — remote search (try "err" for a failure)', style: resolver.ink(t.muted)),
        _comboRow(userView, width: _comboWidth),
        const SizedBox(height: 1),
        // The country field's chrome is the app's: a bordered Container
        // around the combobox row, sized so the whole box is _comboWidth
        // wide. The popup's matching border is the widget's (popupBorder).
        Container(
          width: _comboWidth,
          border: BorderType.rounded,
          borderStyle: resolver.border({if (model.countryCombo.focused) WidgetState.focused}),
          padding: const EdgeInsets.symmetric(horizontal: 1),
          topTitles: [
            Line(
              ' Country — custom rows ',
              style: model.countryCombo.focused ? resolver.ink(t.focus) : resolver.ink(t.muted),
            ),
          ],
          child: _comboRow(countryView),
        ),
        const Expanded(child: SizedBox()),
        Line(model.status.isEmpty ? 'Nothing selected yet' : model.status, style: resolver.ink(t.accent)),
        Line(helpLine, style: resolver.ink(t.muted)),
      ],
    ),
  );

  frame.render(ui);

  // Second pass: whichever combobox is open paints its popup over the tree
  // that just rendered. Each call is a no-op while its own model is closed.
  roleView.renderPopup(frame);
  userView.renderPopup(frame);
  countryView.renderPopup(frame);
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
