import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

import '../../load/load.dart';
import '../list_view/list_view_model.dart';
import '../list_view/types.dart';
import '../popup/popup_placement.dart';
import '../text_input_model.dart';
import 'types.dart';

// ═══════════════════════════════════════════════════════════
// KEY BINDINGS
// ═══════════════════════════════════════════════════════════

/// The popup list's own key binding: navigation and confirm only.
///
/// The default [ListViewModel] bindings include `j`, `k`, `G`, `home`, `end`
/// and `space`, every one of which is ordinary text in a combobox field.
final KeyBinding<ListViewAction> _popupKeyBinding = KeyBinding<ListViewAction>()
  ..map(['up'], ListViewAction.up)
  ..map(['down'], ListViewAction.down)
  ..map(['pageUp'], ListViewAction.pageUp)
  ..map(['pageDown'], ListViewAction.pageDown)
  ..map(['enter'], ListViewAction.confirm);

/// [TextInputAction]s that move the caret without changing the text.
///
/// A key resolving to one of these never counts as an edit: it never opens
/// the popup on its own, and it never clears a pristine committed label.
const Set<TextInputAction> _caretOnlyActions = {
  TextInputAction.home,
  TextInputAction.end,
  TextInputAction.left,
  TextInputAction.right,
  TextInputAction.jumpWordLeft,
  TextInputAction.jumpWordRight,
};

/// The default [ComboboxModel.matches]: a case-insensitive contains on
/// [label].
bool Function(T item, String query) _defaultMatches<T>(String Function(T item) label) =>
    (item, query) => label(item).toLowerCase().contains(query.toLowerCase());

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

/// Model for a combobox: a text field paired with a filterable popup list.
///
/// Holds an embedded [TextInputModel] field and, privately, a [ListViewModel]
/// over [T] that never surfaces on the public API. Options come either in
/// memory (the constructor's `options`) or from the app, one
/// [QueryKey]-addressed [LoadRequest] per query (`options` omitted — see
/// [isRemote]). Typing filters or re-queries, and the popup opens and closes
/// as the keys below describe. Use [update] to handle messages, exactly like
/// any other widget model.
///
/// ```dart
/// final combobox = ComboboxModel<String>(
///   label: (s) => s,
///   options: const ['Apple', 'Banana', 'Cherry'],
///   focused: true,
/// );
/// ```
///
/// Enter commits the popup's highlighted option: the field shows its label,
/// the popup closes, [value] is set, and the model emits
/// [ComboboxSelectCmd] addressed by [id]. The app reads the selection back
/// from [value]; the command carries nothing else.
///
/// A remote combobox asks for options through [Loadable.applyLoad]: every
/// text change, and opening without one, asks with a fresh [QueryKey] naming
/// the query's text, and only an answer for the newest query the model asked
/// installs — a superseded one's answer is dropped. A refusal
/// (`declineLoad`) leaves the current options standing, and an error is kept
/// for the popup's status row until a later query supersedes it.
class ComboboxModel<T> implements Component, Loadable {
  @override
  late final String id;

  /// Stable id of the embedded text field.
  ///
  /// The view stamps this on the field's node, under the combobox's own
  /// scope, so a press addressed to the path `$id/$fieldId` resolves back
  /// here.
  late final String fieldId;

  /// Stable id of the toggle control that opens and closes the popup.
  ///
  /// The view stamps this on the toggle's node the same way [fieldId] is
  /// stamped on the field.
  late final String toggleId;

  /// Renders an option as the text shown in the field and in a popup row.
  final String Function(T item) label;

  /// Whether an option matches a typed query.
  ///
  /// Defaults to a case-insensitive contains on [label]. Override for a
  /// different match rule — matching on a secondary field, a fuzzy match, and
  /// so on.
  final bool Function(T item, String query) matches;

  /// How many popup rows the view shows before scrolling.
  final int maxVisibleRows;

  /// Placeholder text shown in the field when it is empty.
  final String placeholder;

  /// Anatomy overrides for the toggle and the popup background. Mutable so
  /// an app can swap the look at runtime, the way it flips [focused].
  ComboboxStyle styles;

  /// The popup's held placement decision, or null while closed.
  ///
  /// The view sets this every open paint via `renderAnchoredPopup`, so the
  /// popup keeps one side and height for the whole open session; [close]
  /// clears it.
  PopupPlacement? placement;

  /// The embedded text field.
  ///
  /// The combobox owns every decision around it — it emits no commands of its
  /// own, and its `focused` mirrors the combobox's.
  late final TextInputModel field;

  final List<T>? _options;
  late final ListViewModel<T, T> _list;
  final _loads = LoadTracker<QueryKey>();
  QueryKey? _newestKey;

  T? _value;
  bool _isOpen = false;
  bool _focused;

  /// Whether the field currently shows the committed label untouched since it
  /// was last set — by construction, a commit, or a restore.
  ///
  /// The first key that actually edits the text while this is true clears the
  /// field before applying itself, rather than appending to the shown label.
  bool _fieldPristine = true;

  /// Creates a combobox over [options], held in memory, or — when [options]
  /// is omitted — over options the app loads remotely; see [isRemote].
  ///
  /// [value], when given, preselects an option: the field starts showing
  /// [label] of it, and opening the popup without editing places the cursor
  /// on its row (matched against [options] with `==`). A remote combobox has
  /// nothing to match against until an answer lands, so [value] only seeds
  /// the field's label there.
  ComboboxModel({
    required this.label,
    String? id,
    String? fieldId,
    String? toggleId,
    bool Function(T item, String query)? matches,
    List<T>? options,
    T? value,
    this.maxVisibleRows = 5,
    this.placeholder = '',
    this.styles = const ComboboxStyle(),
    bool focused = false,
  }) : matches = matches ?? _defaultMatches(label),
       _options = options == null ? null : List<T>.of(options),
       _value = value,
       _focused = focused {
    this.id = id ?? autoId('combobox');
    this.fieldId = fieldId ?? autoId('combobox-field');
    this.toggleId = toggleId ?? autoId('combobox-toggle');
    field = TextInputModel(
      id: this.fieldId,
      initial: value == null ? '' : label(value),
      placeholder: placeholder,
      focused: focused,
    );
    _list = ListViewModel<T, T>(focused: true, keyBinding: _popupKeyBinding);
  }

  /// Whether the combobox is focused.
  ///
  /// Setting it false takes the same path as [close]: the popup closes and
  /// the field restores the committed label, committing nothing. The
  /// embedded field's own `focused` mirrors this value.
  bool get focused => _focused;

  @override
  set focused(bool value) {
    if (!value) close();
    _focused = value;
    field.focused = value;
  }

  /// Whether the popup is open.
  bool get isOpen => _isOpen;

  /// Whether options come from the app, one [QueryKey]-addressed
  /// [LoadRequest] per query, rather than an in-memory list handed to the
  /// constructor.
  bool get isRemote => _options == null;

  /// Whether the newest query this combobox asked is in flight.
  ///
  /// An older, superseded query may still be finishing in the background;
  /// only the newest one drives the popup's status row.
  bool get isLoadingQuery {
    final key = _newestKey;
    return key != null && _loads.isLoading(key);
  }

  /// The error from the newest query's last answer, or null.
  ///
  /// A later query replaces [_newestKey], so this reads that query's own
  /// state and stops reporting an older one's failure.
  Object? get queryError {
    final key = _newestKey;
    return key == null ? null : _loads.errorFor(key);
  }

  /// The committed option, or null when none stands.
  T? get value => _value;

  /// The field's full hit path — the popup's anchor.
  ///
  /// The view passes this to `renderAnchoredPopup` so the app never builds
  /// path strings by hand.
  String get anchorPath => HitTag.join(id, fieldId);

  /// The toggle's full hit path.
  ///
  /// The view reads its painted rect to size the popup — the union of the
  /// field's and the toggle's rects.
  String get togglePath => HitTag.join(id, toggleId);

  /// The embedded popup list, for the view to render.
  ///
  /// Not part of the combobox's public surface: the list's own item type,
  /// commands and cursor state stay implementation detail — [ComboboxSelectCmd]
  /// is the only command this widget ever emits. Marked [internal] rather
  /// than left off the model because the view, a separate file in this
  /// package, must build a real list widget over it.
  @internal
  ListViewModel<T, T> get internalList => _list;

  /// Sets how many popup rows are visible, for page navigation and scroll
  /// math.
  ///
  /// Call this from the view during paint, once the popup's own height is
  /// known.
  void setVisibleCount(int count) => _list.setVisibleCount(count);

  /// Closes the popup, discarding any unfiled edit.
  ///
  /// Restores the field to the label of the committed value, or to an empty
  /// string when no value stands. A no-op while already closed.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    placement = null;
    final committed = _value;
    _setFieldText(committed == null ? '' : label(committed));
  }

  /// Clears the value and empties the field.
  ///
  /// App-driven: no key binds to this. The popup's open state is untouched.
  void clear() {
    _value = null;
    _setFieldText('');
  }

  /// Handles a message, reporting whether it was consumed and any effect.
  ///
  /// Pointer traffic is resolved by [HitTag.leafOf] against [toggleId],
  /// [fieldId] and the popup list's own id above the focus gate, so the
  /// toggle, click-to-caret and popup rows all work whether or not the
  /// combobox is focused. A press on the bare scope path — a blank popup row,
  /// or the scope's own untagged cells — is consumed and does nothing: no
  /// caret move, no commit, no close. Keyboard handling sits behind the
  /// gate: while closed, a text-editing key or Down opens the popup and
  /// Enter/Esc are declined for the app; while open, Up/Down/PageUp/PageDown
  /// move the popup cursor, Enter commits, Esc closes and restores, and every
  /// other key edits the field.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) return _handlePointer(pointer);
    if (msg is PointerLeaveMsg) return _forwardToListIfAddressed(msg, msg.targetId);
    if (msg case PointerCancelMsg(:final targetId?)) return _forwardToListIfAddressed(msg, targetId);
    if (msg is PointerCancelMsg) return const Declined();

    if (!focused) return const Declined();

    if (msg case final KeyMsg key) {
      return isOpen ? _handleOpenKey(key) : _handleClosedKey(key);
    }

    return const Declined();
  }

  UpdateResult _handlePointer(PointerMsg pointer) {
    final targetId = pointer.targetId;
    if (targetId == null) return const Declined();
    // The bare scope path: our own untagged cells, or a blank popup row past
    // the last match. Ours to consume — nothing behind the popup should react
    // to a click on its own chrome — but there is nothing to do with it.
    if (targetId == id) return const Handled();

    final leaf = HitTag.leafOf(targetId);

    if (leaf == toggleId) {
      if (!pointer.isDown) return const Declined();
      if (isOpen) {
        close();
        return const Handled();
      }
      return Handled(_open());
    }

    if (leaf == fieldId) return field.update(pointer);

    if (leaf == _list.id) return _commitFromList(_list.update(pointer));

    return const Declined();
  }

  /// Forwards [msg] to the popup list when [targetId]'s leaf names it —
  /// clearing its hover on a leave, ending a held gesture on a cancel — and
  /// declines otherwise.
  UpdateResult _forwardToListIfAddressed(Msg msg, String targetId) =>
      HitTag.leafOf(targetId) == _list.id ? _list.update(msg) : const Declined();

  UpdateResult _handleClosedKey(KeyMsg msg) {
    if (msg.key == 'enter' || msg.key == 'escape') return const Declined();
    if (msg.key == 'down') return Handled(_open());
    if (!_isFieldEditingKey(msg)) return const Declined();

    // The field shows exactly the committed label while closed, so the first
    // edit always starts from empty.
    field
      ..clear()
      ..update(msg);
    _fieldPristine = false;
    _isOpen = true;
    if (isRemote) return Handled(_askQuery(field.value));
    _reseedFilter();
    return const Handled();
  }

  UpdateResult _handleOpenKey(KeyMsg msg) {
    switch (msg.key) {
      case 'up':
      case 'down':
      case 'pageUp':
      case 'pageDown':
        return _list.update(msg);
      case 'enter':
        return _commit(msg);
      case 'escape':
        close();
        return const Handled();
      default:
        return _editField(msg);
    }
  }

  UpdateResult _editField(KeyMsg msg) {
    if (!_isFieldEditingKey(msg)) return field.update(msg);

    if (_fieldPristine) {
      field.clear();
      _fieldPristine = false;
    }
    final before = field.value;
    final result = field.update(msg);
    if (field.value == before) return result;

    if (!isRemote) {
      _reseedFilter();
      return result;
    }
    final ask = _askQuery(field.value);
    final fieldCmd = result is Handled ? result.cmd : null;
    return Handled(fieldCmd == null ? ask : Batch([fieldCmd, ask]));
  }

  UpdateResult _commit(KeyMsg msg) => _commitFromList(_list.update(msg));

  /// Turns the popup list's own verdict into the combobox's: a declined or
  /// bare-Handled result (nothing at the cursor, a wheel scroll, a hover
  /// move) passes through unchanged, and a [ListActionCmd] — the list's
  /// Enter and its row press both produce one — commits the cursor item as
  /// the value, closes the popup, and re-addresses the effect as
  /// [ComboboxSelectCmd] so a click and a keyboard Enter are indistinguishable
  /// to the app.
  UpdateResult _commitFromList(UpdateResult result) {
    if (result is! Handled || result.cmd is! ListActionCmd) return result;

    final item = _list.cursorItem;
    if (item == null) return const Handled();

    _value = item;
    _isOpen = false;
    placement = null;
    _setFieldText(label(item));
    return Handled(ComboboxSelectCmd(id));
  }

  /// Whether [msg] would change the field's text — a bound editing action, or
  /// plain typed text. A bound but caret-only action (Home, Left, …) and an
  /// otherwise-unbound key (Tab) both answer false.
  bool _isFieldEditingKey(KeyMsg msg) {
    final action = field.keyBinding.resolve(msg);
    if (action != null) return !_caretOnlyActions.contains(action);
    return msg.text != null;
  }

  /// Opens the popup unfiltered: from [_options] when local, or by asking the
  /// app for the empty [QueryKey] when [isRemote].
  Cmd? _open() {
    if (isRemote) {
      _isOpen = true;
      return _askQuery('');
    }
    _openUnfiltered();
    return null;
  }

  void _openUnfiltered() {
    _isOpen = true;
    final options = _options!;
    _list
      ..reset()
      ..insertItems(options, 0)
      ..totalCount = options.length;

    final current = _value;
    if (current == null) return;
    final index = options.indexWhere((option) => option == current);
    if (index >= 0) _list.moveCursorTo(index);
  }

  void _reseedFilter() {
    final query = field.value;
    final filtered = _options!.where((option) => matches(option, query)).toList();
    _list
      ..reset()
      ..insertItems(filtered, 0)
      ..totalCount = filtered.length;
  }

  /// Asks the app for options matching [query], remembering the key as the
  /// newest one asked — the one whose answer [applyLoad] is willing to
  /// install.
  LoadRequest _askQuery(String query) {
    final key = QueryKey(query);
    _newestKey = key;
    _loads.begin(key);
    return LoadRequest(id, key: key);
  }

  /// Replaces the popup's options wholesale with a query's answer, cursor on
  /// the first row.
  void _installRemoteOptions(List<T> options) {
    _list
      ..reset()
      ..insertItems(options, 0)
      ..totalCount = options.length;
  }

  /// Installs a remote query's answer, or records its failure.
  ///
  /// Only an answer for the newest query the model asked — [_newestKey] —
  /// installs, so a superseded query landing after a newer one was asked is
  /// dropped once its own slot resolves; a query no longer in flight (e.g.
  /// already answered) is dropped outright. A refusal clears the slot and
  /// installs nothing, leaving the current options standing. A failure is
  /// kept for [queryError], which the popup reads only while its key is
  /// still the newest one.
  @override
  void applyLoad(LoadResult<Object?> result) {
    if (result.id != id) return;
    final key = result.key;
    if (key is! QueryKey) return;
    if (!_loads.isLoading(key)) return;

    if (result.cancelled) {
      _loads.complete(key);
      return;
    }
    if (!result.ok) {
      _loads.fail(key, result.error!);
      return;
    }
    _loads.complete(key);
    if (key != _newestKey) return;

    final data = result.data;
    _installRemoteOptions(data is List<T> ? data : const []);
  }

  /// Rewrites the field's text outright.
  ///
  /// Used to restore the committed label and to write a fresh one — both of
  /// which must work even while the combobox is not focused (a [close] the
  /// app drives directly, say). [TextInputModel.value]'s setter is a direct
  /// call, not a message, so it needs no focus juggling to reach an
  /// unfocused field.
  void _setFieldText(String text) {
    field.value = text;
    _fieldPristine = true;
  }
}
