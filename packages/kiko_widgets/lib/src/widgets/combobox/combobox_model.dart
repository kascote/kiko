import 'package:kiko/kiko.dart';

import '../list_view/list_view_model.dart';
import '../list_view/types.dart';
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
/// over [T] that never surfaces on the public API. Options are held in
/// memory; typing filters them with [matches], and the popup opens and closes
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

  /// The embedded text field.
  ///
  /// The combobox owns every decision around it — it emits no commands of its
  /// own, and its `focused` mirrors the combobox's.
  late final TextInputModel field;

  final List<T> _options;
  late final ListViewModel<T, T> _list;

  T? _value;
  bool _isOpen = false;
  bool _focused;

  /// Whether the field currently shows the committed label untouched since it
  /// was last set — by construction, a commit, or a restore.
  ///
  /// The first key that actually edits the text while this is true clears the
  /// field before applying itself, rather than appending to the shown label.
  bool _fieldPristine = true;

  /// Creates a combobox over [options], held in memory.
  ///
  /// [value], when given, preselects an option: the field starts showing
  /// [label] of it, and opening the popup without editing places the cursor
  /// on its row (matched against [options] with `==`).
  ComboboxModel({
    required this.label,
    String? id,
    String? fieldId,
    String? toggleId,
    bool Function(T item, String query)? matches,
    List<T> options = const [],
    T? value,
    this.maxVisibleRows = 5,
    this.placeholder = '',
    bool focused = false,
  }) : matches = matches ?? _defaultMatches(label),
       _options = List<T>.of(options),
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

  /// The committed option, or null when none stands.
  T? get value => _value;

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
  /// Pointer traffic is resolved by [HitTag.leafOf] against [toggleId] and
  /// [fieldId] above the focus gate, so the toggle and click-to-caret work
  /// whether or not the combobox is focused. Keyboard handling sits behind
  /// the gate: while closed, a text-editing key or Down opens the popup and
  /// Enter/Esc are declined for the app; while open, Up/Down/PageUp/PageDown
  /// move the popup cursor, Enter commits, Esc closes and restores, and every
  /// other key edits the field.
  @override
  UpdateResult update(Msg msg) {
    if (msg case final PointerMsg pointer) return _handlePointer(pointer);
    if (msg is PointerLeaveMsg) return const Declined();
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
    final leaf = HitTag.leafOf(targetId);

    if (leaf == toggleId) {
      if (!pointer.isDown) return const Declined();
      if (isOpen) {
        close();
      } else {
        _openUnfiltered();
      }
      return const Handled();
    }

    if (leaf == fieldId) return field.update(pointer);

    return const Declined();
  }

  UpdateResult _handleClosedKey(KeyMsg msg) {
    if (msg.key == 'enter' || msg.key == 'escape') return const Declined();
    if (msg.key == 'down') {
      _openUnfiltered();
      return const Handled();
    }
    if (!_isFieldEditingKey(msg)) return const Declined();

    // The field shows exactly the committed label while closed, so the first
    // edit always starts from empty.
    field
      ..clear()
      ..update(msg);
    _fieldPristine = false;
    _isOpen = true;
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
    if (field.value != before) _reseedFilter();
    return result;
  }

  UpdateResult _commit(KeyMsg msg) {
    final result = _list.update(msg);
    if (result is! Handled || result.cmd == null) return const Handled();

    final item = _list.cursorItem;
    if (item == null) return const Handled();

    _value = item;
    _isOpen = false;
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

  void _openUnfiltered() {
    _isOpen = true;
    _list
      ..reset()
      ..insertItems(_options, 0)
      ..totalCount = _options.length;

    final current = _value;
    if (current == null) return;
    final index = _options.indexWhere((option) => option == current);
    if (index >= 0) _list.moveCursorTo(index);
  }

  void _reseedFilter() {
    final query = field.value;
    final filtered = _options.where((option) => matches(option, query)).toList();
    _list
      ..reset()
      ..insertItems(filtered, 0)
      ..totalCount = filtered.length;
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
