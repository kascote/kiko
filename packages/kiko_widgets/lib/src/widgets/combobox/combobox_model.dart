import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

import '../../load/load.dart';
import '../list_view/list_view_model.dart';
import '../list_view/types.dart';
import '../popup/popup_placed.dart';
import '../popup/popup_placement.dart';
import '../text_input/text_input_model.dart';
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
/// [ComboboxSelectEvent] addressed by [id]. The app reads the selection back
/// from [value]; the event carries nothing else.
///
/// A remote combobox asks for options with a [LoadRequest]: every text
/// change, and opening without one, asks with a fresh [QueryKey] naming the
/// query's text. The answer comes back as a [LoadResult] through [update].
/// Asking clears the popup, so it only ever shows the current query's state —
/// [queryStatus] — and only an answer for the newest query installs; a
/// superseded one's answer is dropped. A refusal (`declineLoad`) resolves the
/// query without installing, leaving the popup stalled until the next query.
class ComboboxModel<T> implements Component {
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

  /// The popup's held placement decision, or null while closed.
  ///
  /// The popup's paint reports a [PopupPlaced] whenever it decides a
  /// placement this model does not hold, and [update] stores it here, so the
  /// popup keeps one side and height for the whole open session; [close]
  /// clears it.
  PopupPlacement? placement;

  /// Whether the pointer is over the toggle.
  ///
  /// Set by a move or drag over the toggle, cleared by a leave. The toggle
  /// acts on the down, so it has no held phase and takes no `pressed`.
  bool toggleHovered = false;

  /// The embedded text field.
  ///
  /// The combobox owns every decision around it — it emits no events of its
  /// own, and its `focused` mirrors the combobox's.
  late final TextInputModel field;

  final List<T>? _options;
  late final ListViewModel<T, T> _list;
  final _loads = LoadTracker<QueryKey>();
  QueryKey? _newestKey;

  /// Whether the newest query's answer has installed.
  ///
  /// Distinguishes an installed empty answer (ready) from a refusal
  /// (stalled), which leave the same empty popup behind.
  bool _newestInstalled = false;

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
  /// on its row, matched with `==`. A remote combobox applies the same rule
  /// when that open's answer installs. A fresh instance from a fetch still
  /// matches, because the comparison is `==`, not identity.
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

  /// Where the newest query stands, in the shared [SliceStatus] vocabulary.
  ///
  /// [SliceStatus.filling] while the newest query is in flight,
  /// [SliceStatus.failed] after its answer failed, [SliceStatus.stalled]
  /// when it resolved without installing — a refusal — and
  /// [SliceStatus.ready] otherwise. An older, superseded query never drives
  /// this, and an in-memory combobox never leaves ready.
  SliceStatus get queryStatus {
    final key = _newestKey;
    if (key == null) return SliceStatus.ready;
    if (_loads.isLoading(key)) return SliceStatus.filling;
    if (_loads.errorFor(key) != null) return SliceStatus.failed;
    return _newestInstalled ? SliceStatus.ready : SliceStatus.stalled;
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
  /// events and cursor state stay implementation detail — [ComboboxSelectEvent]
  /// is the only event this widget ever emits. Marked [internal] rather
  /// than left off the model because the view, a separate file in this
  /// package, must build a real list widget over it.
  @internal
  ListViewModel<T, T> get internalList => _list;

  /// The query slots.
  ///
  /// Exposed for testing — slot bookkeeping is otherwise invisible.
  /// Production reads go through [queryStatus] and [queryError].
  @visibleForTesting
  LoadTracker<QueryKey> get queryLoads => _loads;

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
  /// App-driven: no key binds to this. The popup's open state is untouched,
  /// but an open popup reseeds so its rows match the now-empty field: an
  /// in-memory combobox shows the unfiltered options again, and a remote one
  /// asks the empty query, clearing the popup to that query's state. Forward
  /// the returned request like one from [update]'s events; it is null except
  /// on that remote path.
  LoadRequest? clear() {
    _value = null;
    _setFieldText('');
    if (!_isOpen) return null;
    if (isRemote) return _askQuery('');
    _seedUnfiltered();
    return null;
  }

  /// Handles a message, reporting whether it was consumed and any effect.
  ///
  /// Pointer traffic is resolved by [HitTag.partOn] against [toggleId],
  /// [fieldId] and the popup list's own id above the focus gate. The part is
  /// the path segment right after the combobox's own id, so the toggle,
  /// click-to-caret and popup rows all work whether or not the combobox is
  /// focused. A press on the bare scope path — a blank popup row, or the
  /// scope's own untagged cells — is consumed and does nothing: no caret
  /// move, no commit, no close. A move over the toggle sets [toggleHovered];
  /// a leave over it clears the flag; a wheel over it is declined, so a
  /// scrollable ancestor gets it. An [Addressed] message whose id names the
  /// popup list — the part after the combobox's own id — is forwarded to the
  /// list; a [LoadResult] addressed to the combobox itself installs a remote
  /// query's answer, or records its failure; a [PopupPlaced] addressed to it
  /// stores the popup's placement; one addressed to any other id is
  /// declined. Keyboard handling sits behind the gate: while closed, a
  /// text-editing key or Down opens the popup and Enter/Esc are declined for
  /// the app; while open, Up/Down/PageUp/PageDown move the popup cursor,
  /// Enter commits, Esc closes and restores, and every other key edits the
  /// field.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) return _handlePointer(pointer);
    if (msg case final PointerLeaveMsg leave) {
      if (HitTag.partOn(leave.targetId, under: id, parts: {toggleId, _list.id}) == toggleId) {
        toggleHovered = false;
        return const Handled();
      }
      return _forwardToListIfAddressed(leave, leave.targetId);
    }
    if (msg case PointerCancelMsg(:final targetId?)) return _forwardToListIfAddressed(msg, targetId);
    if (msg is PointerCancelMsg) return const Declined();
    // A part is forwarded to before the guard below asks whether the message
    // is the combobox's own.
    if (msg case Addressed(id: final path) when HitTag.partOn(path, under: id, parts: {_list.id}) == _list.id) {
      return _fromList(_list.update(msg));
    }
    if (msg case final LoadResult<Object?> result) return _applyLoad(result);
    if (msg case final PopupPlaced report) return _applyPlacement(report);

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

    switch (HitTag.partOn(targetId, under: id, parts: {toggleId, fieldId, _list.id})) {
      case final part when part == toggleId:
        if (pointer.isWheel) return const Declined();
        if (!pointer.isDown) {
          toggleHovered = true;
          return const Handled();
        }
        if (isOpen) {
          close();
          return const Handled();
        }
        final request = _open();
        return request == null ? const Handled() : Handled.event(request);
      case final part when part == fieldId:
        return field.update(pointer);
      case final part when part == _list.id:
        return _commitFromList(_list.update(pointer));
      case _:
        return const Declined();
    }
  }

  /// Forwards [msg] to the popup list when [path] names it — a pointer
  /// leaving or cancelling over the list, an [Addressed] message naming it —
  /// and declines otherwise.
  UpdateResult _forwardToListIfAddressed(Msg msg, String path) =>
      HitTag.partOn(path, under: id, parts: {_list.id}) == _list.id ? _fromList(_list.update(msg)) : const Declined();

  UpdateResult _handleClosedKey(KeyMsg msg) {
    if (msg.key == 'enter' || msg.key == 'escape') return const Declined();
    if (msg.key == 'down') {
      final request = _open();
      return request == null ? const Handled() : Handled.event(request);
    }
    if (!_isFieldEditingKey(msg)) return const Declined();

    // The field shows exactly the committed label while closed, so the first
    // edit always starts from empty.
    field
      ..clear()
      ..update(msg);
    _fieldPristine = false;
    _isOpen = true;
    if (isRemote) return Handled.event(_askQuery(field.value));
    _reseedFilter();
    return const Handled();
  }

  UpdateResult _handleOpenKey(KeyMsg msg) {
    switch (msg.key) {
      case 'up':
      case 'down':
      case 'pageUp':
      case 'pageDown':
        return _fromList(_list.update(msg));
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
    // The field emits no events of its own, so the ask is the only effect.
    return Handled.event(_askQuery(field.value));
  }

  UpdateResult _commit(KeyMsg msg) => _commitFromList(_list.update(msg));

  /// Funnels the popup list's [UpdateResult] out of the combobox.
  ///
  /// Every result the list produces leaves the combobox through here,
  /// whether forwarded outright or turned into a commit by
  /// [_commitFromList]. It scopes a [Tick] the list armed under the
  /// combobox's own id. The list only knows its own bare id, not any
  /// wrapping scope.
  UpdateResult _fromList(UpdateResult result) => result.scopeTicks(id);

  /// Turns the popup list's own verdict into the combobox's, after routing it
  /// through [_fromList]. A declined result passes through unchanged, and a
  /// [ListActivateEvent] in the list's events — its Enter and its row press
  /// both produce one — commits the cursor item as the value, closes the
  /// popup, and re-addresses the effect as [ComboboxSelectEvent] so a click
  /// and a keyboard Enter are indistinguishable to the app. A wheel scroll or
  /// a hover move carries no event. Any other event the list produces is
  /// absorbed here, so no part's event leaks past the combobox; its command leaves scoped by
  /// [_fromList].
  UpdateResult _commitFromList(UpdateResult result) {
    final funneled = _fromList(result);
    if (funneled is! Handled) return funneled;
    if (!funneled.events.any((event) => event is ListActivateEvent)) {
      return Handled(cmd: funneled.cmd);
    }

    final item = _list.cursorItem;
    if (item == null) return const Handled();

    _value = item;
    _isOpen = false;
    placement = null;
    _setFieldText(label(item));
    return Handled.event(ComboboxSelectEvent(id));
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
  LoadRequest? _open() {
    if (isRemote) {
      _isOpen = true;
      return _askQuery('');
    }
    _openUnfiltered();
    return null;
  }

  void _openUnfiltered() {
    _isOpen = true;
    _seedUnfiltered();
  }

  /// Seeds the popup with the full in-memory set, cursor on the value's row.
  void _seedUnfiltered() {
    final options = _options!;
    _list
      ..reset()
      ..insertItems(options, 0)
      ..totalCount = options.length;
    _moveCursorToValue(options);
  }

  /// Moves the popup cursor to the current value's row, when [options] holds
  /// an option equal (`==`) to it. Leaves the cursor alone otherwise.
  void _moveCursorToValue(List<T> options) {
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

  /// Asks the app for options matching [query], clearing the popup so it
  /// shows only this query's state, and remembering the key as the newest
  /// one asked — the one whose answer [update] is willing to install.
  ///
  /// The superseded key's slot is dropped unless it is still in flight;
  /// [update] needs a loading slot to resolve and drop that query's late
  /// answer. Without the drop, one failed slot per distinct query text would
  /// pile up for the life of the model.
  LoadRequest _askQuery(String query) {
    _list
      ..reset()
      ..totalCount = 0;
    _newestInstalled = false;
    final key = QueryKey(query);
    final superseded = _newestKey;
    if (superseded != null && superseded != key && !_loads.isLoading(superseded)) {
      _loads.complete(superseded);
    }
    _newestKey = key;
    _loads.begin(key);
    return LoadRequest(id, key: key);
  }

  /// Replaces the popup's options wholesale with a query's answer.
  ///
  /// The cursor lands on the first row. After an open without editing — the
  /// field still pristine, so the answer is the empty query's — it lands on
  /// the current value's row instead, when the answer holds an equal option.
  void _installRemoteOptions(List<T> options) {
    _list
      ..reset()
      ..insertItems(options, 0)
      ..totalCount = options.length;
    if (_fieldPristine) _moveCursorToValue(options);
  }

  /// Installs a remote query's answer, or records its failure.
  ///
  /// A result whose id's leaf is not this combobox's id is declined: it is
  /// not a message this combobox understands. Every result that is its own is
  /// consumed.
  /// Only an answer for the newest query the model asked — [_newestKey] —
  /// installs, so a superseded query landing after a newer one was asked is
  /// dropped once its own slot resolves; a query no longer in flight (e.g.
  /// already answered) is dropped outright. A refusal clears the slot and
  /// installs nothing, leaving the popup stalled. A failure is kept for
  /// [queryError] only while its key is the newest one; a superseded
  /// query's failure clears its slot like a refusal.
  ///
  /// A successful answer must carry a `List<T>`. Any other payload, null
  /// included, fails the newest key's slot with a [PayloadMismatch] and
  /// installs nothing, so [queryError] reports the wiring error where a fetch
  /// failure would show.
  UpdateResult _applyLoad(LoadResult<Object?> result) {
    if (HitTag.leafOf(result.id) != id) return const Declined();
    final key = result.key;
    if (key is! QueryKey) return const Handled();
    if (!_loads.isLoading(key)) return const Handled();

    if (result.cancelled) {
      _loads.complete(key);
      return const Handled();
    }
    if (!result.ok) {
      // A superseded key's error would never surface — [queryError] reads
      // only the newest key — so keeping it would only leak the slot.
      if (key == _newestKey) {
        _loads.fail(key, result.error!);
      } else {
        _loads.complete(key);
      }
      return const Handled();
    }
    if (key != _newestKey) {
      _loads.complete(key);
      return const Handled();
    }
    final mismatch = payloadMismatch(
      result,
      widget: 'Combobox',
      expected: 'List<$T>',
      accepts: (data) => data is List<T>,
    );
    if (mismatch != null) {
      _loads.fail(key, mismatch);
      return const Handled();
    }
    _loads.complete(key);
    _newestInstalled = true;
    _installRemoteOptions(result.data! as List<T>);
    return const Handled();
  }

  /// Stores the placement the popup was last painted with.
  ///
  /// A report whose id's leaf is not this combobox's id is declined. One that
  /// lands after the popup closed is consumed and dropped: [close] cleared
  /// the decision on purpose, and the next open decides afresh.
  UpdateResult _applyPlacement(PopupPlaced report) {
    if (HitTag.leafOf(report.id) != id) return const Declined();
    if (_isOpen) placement = report.placement;
    return const Handled();
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
