import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';
import '../../support/viewport.dart';

/// Helper to create a KeyMsg for a named key.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// Helper to create a KeyMsg for a plain typed character.
KeyMsg charMsg(String c) => KeyMsg(c, text: c);

/// A routed button-down addressed to [targetId], on no marked part.
PointerMsg pressOn(String targetId) =>
    PointerMsg(global: Position.origin, action: PointerAction.down, local: Position.origin, targetId: targetId);

/// A routed move addressed to [targetId] — not a press.
PointerMsg moveOn(String targetId) =>
    PointerMsg(global: Position.origin, action: PointerAction.move, local: Position.origin, targetId: targetId);

/// An option with value equality, standing in for a rich remote record: two
/// fetches produce equal but non-identical instances.
@immutable
class RemoteOption {
  /// Creates an option; deliberately non-const so instances never canonicalize.
  // ignore: prefer_const_constructors_in_immutables
  RemoteOption(this.id, this.name);

  /// The identity the equality runs on.
  final int id;

  /// The label shown in the field and the popup rows.
  final String name;

  @override
  bool operator ==(Object other) => other is RemoteOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A message no model understands: the probe for the decline path.
class _UnknownMsg extends Msg {
  const _UnknownMsg();
}

void main() {
  group('ComboboxModel', () {
    ComboboxModel<String> fruitBox({
      List<String> options = const ['Apple', 'Banana', 'Cherry', 'Date'],
      String? value,
      bool focused = true,
    }) => ComboboxModel<String>(
      id: 'combo',
      fieldId: 'combo-field',
      toggleId: 'combo-toggle',
      label: (s) => s,
      options: options,
      value: value,
      focused: focused,
    );

    group('construction', () {
      test('default state is closed with an empty field', () {
        final combo = fruitBox();
        expect(combo.isOpen, isFalse);
        expect(combo.value, isNull);
        expect(combo.field.value, isEmpty);
        expect(combo.maxVisibleRows, equals(5));
      });

      test('a preselected value seeds the field with its label', () {
        final combo = fruitBox(value: 'Cherry');
        expect(combo.field.value, equals('Cherry'));
        expect(combo.value, equals('Cherry'));
      });

      test('a custom matches override replaces the default contains rule', () {
        final combo = ComboboxModel<int>(
          id: 'nums',
          fieldId: 'nums-field',
          toggleId: 'nums-toggle',
          label: (n) => n.toString(),
          matches: (n, query) => query.isNotEmpty && n.toString().endsWith(query),
          options: const [1, 21, 31, 42],
          focused: true,
        )..update(charMsg('1'));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals(1), reason: '1, 21 and 31 all end with "1"; the first match commits');
      });
    });

    group('opening', () {
      test('a text-editing key while closed opens the popup and inserts', () {
        final combo = fruitBox();
        final result = combo.update(charMsg('a'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
        expect(combo.field.value, equals('a'));
      });

      test('down while closed opens unfiltered, leaving the field untouched', () {
        final combo = fruitBox();
        final result = combo.update(keyMsg('down'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
        expect(combo.field.value, isEmpty);
      });

      test('a toggle press opens the popup while closed', () {
        final combo = fruitBox();
        final result = combo.update(pressOn('combo-toggle'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
      });

      test('a toggle press works even when the combobox itself is unfocused', () {
        final combo = fruitBox(focused: false);
        final result = combo.update(pressOn('combo-toggle'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
      });

      test('a toggle press resolves through a scoped path by its leaf id', () {
        final combo = fruitBox();
        final result = combo.update(pressOn('combo/combo-toggle'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue);
      });

      test('a non-down pointer on the toggle is declined', () {
        expect(fruitBox().update(moveOn('combo-toggle')), isA<Declined>());
      });

      test('a navigation key with nothing bound (e.g. tab) is declined while closed', () {
        expect(fruitBox().update(keyMsg('tab')), isA<Declined>());
      });
    });

    group('closed keys the app keeps', () {
      test('enter is declined while closed', () {
        expect(fruitBox().update(keyMsg('enter')), isA<Declined>());
      });

      test('escape is declined while closed', () {
        expect(fruitBox().update(keyMsg('escape')), isA<Declined>());
      });
    });

    group('toggle closes an open popup', () {
      test('a toggle press while open closes and restores the committed label', () {
        final combo = fruitBox(value: 'Banana')..update(keyMsg('down'));

        final result = combo.update(pressOn('combo-toggle'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isFalse);
        expect(combo.field.value, equals('Banana'));
      });
    });

    group('open-key forwarding', () {
      test('down moves the popup cursor forward', () {
        final combo = fruitBox()
          ..update(keyMsg('down')) // opens, cursor on row 0 (Apple)
          ..update(keyMsg('down')); // cursor on row 1 (Banana)

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals('Banana'));
      });

      test('up moves the popup cursor back', () {
        final combo = fruitBox()
          ..update(keyMsg('down'))
          ..update(keyMsg('down'))
          ..update(keyMsg('down')) // cursor on row 2 (Cherry)
          ..update(keyMsg('up')) // cursor on row 1 (Banana)
          ..update(keyMsg('enter'));

        expect(combo.value, equals('Banana'));
      });

      test('pageDown moves the cursor by the seeded visible count', () {
        final combo = fruitBox()
          ..update(keyMsg('down'))
          ..internalList.viewport(rows: 2)
          ..update(keyMsg('pageDown')) // cursor row 0 + 2 = row 2 (Cherry)
          ..update(keyMsg('enter'));

        expect(combo.value, equals('Cherry'));
      });

      test('pageUp moves the cursor back by the seeded visible count', () {
        final combo = fruitBox()
          ..update(keyMsg('down'))
          ..internalList.viewport(rows: 2)
          ..update(keyMsg('pageDown')) // row 2
          ..update(keyMsg('pageUp')) // row 0
          ..update(keyMsg('enter'));

        expect(combo.value, equals('Apple'));
      });
    });

    group('filtering', () {
      test('typing narrows the popup and re-seeds with the cursor on the first match', () {
        final combo = fruitBox()
          ..update(charMsg('C'))
          ..update(charMsg('h'));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals('Cherry'));
        expect(combo.field.value, equals('Cherry'));
        expect(combo.isOpen, isFalse);
      });

      test('a filter change resets the cursor to the first match, even with a value selected', () {
        final combo = fruitBox(value: 'Date')..update(charMsg('a'));

        // Case-insensitive contains 'a': Apple, Banana, Date all match, in list
        // order — the filter ignores the prior value entirely.
        final result = combo.update(keyMsg('enter'));
        expect(combo.value, equals('Apple'));
        expect(result, isA<Handled>());
      });
    });

    group('opening without editing', () {
      test('places the cursor on the current value, not the first row', () {
        final combo = fruitBox(value: 'Cherry')..update(keyMsg('down'));

        // An unmoved commit lands on whatever row the cursor opened on.
        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals('Cherry'));
      });

      test('lands on the first row when no value stands', () {
        final combo = fruitBox()..update(keyMsg('down'));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>());
        expect(combo.value, equals('Apple'));
      });
    });

    group('commit', () {
      test('commit with no cursor row (empty options) is a bare Handled', () {
        final combo = fruitBox(options: const [])..update(keyMsg('down'));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
        expect(combo.value, isNull);
        expect(combo.isOpen, isTrue, reason: 'nothing was committed, so nothing closes');
      });

      test('the emitted command addresses the combobox, never the embedded list', () {
        final combo = fruitBox()..update(keyMsg('down'));

        final result = combo.update(keyMsg('enter')) as Handled;
        final cmd = result.cmd! as ComboboxSelectCmd;
        expect(cmd.id, equals('combo'));
        expect(cmd, isNot(isA<ListActionCmd>()));
      });
    });

    group('escape restores', () {
      test('esc while open restores the committed label and closes, committing nothing', () {
        final combo = fruitBox(value: 'Banana')
          ..update(keyMsg('down'))
          ..update(keyMsg('down')); // cursor now on Cherry, uncommitted

        final result = combo.update(keyMsg('escape'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isFalse);
        expect(combo.field.value, equals('Banana'));
        expect(combo.value, equals('Banana'));
      });

      test('esc with no prior value restores the field to empty', () {
        final combo = fruitBox()
          ..update(charMsg('a'))
          ..update(keyMsg('escape'));

        expect(combo.field.value, isEmpty);
        expect(combo.value, isNull);
      });
    });

    group('first edit over a committed label', () {
      test('replaces the label instead of appending to it, while closed', () {
        final combo = fruitBox(value: 'Banana');

        final result = combo.update(charMsg('x'));

        expect(result, isA<Handled>());
        expect(combo.field.value, equals('x'));
      });

      test('replaces the label instead of appending to it, once opened unfiltered', () {
        final combo = fruitBox(value: 'Banana')
          ..update(keyMsg('down'))
          ..update(charMsg('x'));

        expect(combo.field.value, equals('x'));
      });

      test('a second edit appends normally', () {
        final combo = fruitBox(value: 'Banana')
          ..update(keyMsg('down'))
          ..update(charMsg('x'))
          ..update(charMsg('y'));

        expect(combo.field.value, equals('xy'));
      });
    });

    group('focus loss', () {
      test('closes the popup and restores the committed label without committing', () {
        final combo = fruitBox(value: 'Banana')
          ..update(keyMsg('down'))
          ..update(keyMsg('down')) // cursor moved, nothing committed
          ..focused = false;

        expect(combo.isOpen, isFalse);
        expect(combo.field.value, equals('Banana'));
        expect(combo.value, equals('Banana'));
        expect(combo.field.focused, isFalse);
      });

      test('regaining focus mirrors onto the field', () {
        final combo = fruitBox()
          ..focused = false
          ..focused = true;

        expect(combo.field.focused, isTrue);
      });
    });

    group('clear', () {
      test('clears the value and empties the field', () {
        final combo = fruitBox(value: 'Banana');

        expect(combo.clear(), isNull);
        expect(combo.value, isNull);
        expect(combo.field.value, isEmpty);
      });

      test('while open, reseeds the popup with the unfiltered options', () {
        final combo = ComboboxModel<int>(
          id: 'nums',
          fieldId: 'nums-field',
          toggleId: 'nums-toggle',
          label: (n) => n.toString(),
          // Rejects the empty query, so only a true unfiltered reseed — not a
          // re-filter on the emptied field — can bring every option back.
          matches: (n, query) => query.isNotEmpty && n.toString().endsWith(query),
          options: const [1, 21, 31, 42],
          focused: true,
        )..update(charMsg('2')); // opens; narrows to 42 alone

        expect(combo.clear(), isNull);
        expect(combo.isOpen, isTrue, reason: 'clear never touches the open state');
        expect(combo.field.value, isEmpty);

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals(1), reason: 'the full set returned, cursor on the first row');
      });
    });

    group('field pointer forwarding', () {
      test('a press addressed to the field leaf places the caret', () {
        final combo = fruitBox(value: 'Banana');
        final press = PointerMsg(
          global: const Position(2, 0),
          action: PointerAction.down,
          local: const Position(2, 0),
          targetId: 'combo-field',
          targetRect: Rect.create(x: 0, y: 0, width: 10, height: 1),
        );

        final result = combo.update(press);

        expect(result, isA<Handled>());
        expect(combo.field.cursor, equals(2));
      });

      test('a pointer addressed to neither part is declined', () {
        expect(fruitBox().update(pressOn('somewhere-else')), isA<Declined>());
      });

      test('a pointer with no target at all is declined', () {
        final combo = fruitBox();
        const noTarget = PointerMsg(global: Position.origin, action: PointerAction.down, local: Position.origin);
        expect(combo.update(noTarget), isA<Declined>());
      });
    });

    group('popup pointer forwarding', () {
      /// A routed pointer [action] addressed to the popup list's own path
      /// (under the combobox's scope), optionally on a row region.
      PointerMsg onList(ComboboxModel<String> combo, PointerAction action, {int? row}) => PointerMsg(
        global: Position.origin,
        action: action,
        local: Position.origin,
        targetId: HitTag.join(combo.id, combo.internalList.id),
        region: row == null ? null : RowRegion(row),
      );

      test('a click on a popup row commits it, exactly like Enter', () {
        final combo = fruitBox()..update(keyMsg('down')); // opens unfiltered

        final result = combo.update(onList(combo, PointerAction.down, row: 1)); // Banana

        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect((result as Handled).cmd! as ComboboxSelectCmd, ComboboxSelectCmd(combo.id));
        expect(combo.value, equals('Banana'));
        expect(combo.field.value, equals('Banana'));
        expect(combo.isOpen, isFalse);
        expect(combo.placement, isNull);
      });

      test('a click on a row the window does not hold is consumed but commits nothing', () {
        final combo = fruitBox(options: const [])..update(keyMsg('down'));

        final result = combo.update(onList(combo, PointerAction.down, row: 0));

        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
        expect(combo.value, isNull);
        expect(combo.isOpen, isTrue);
      });

      test('a press on the bare scope path does nothing — no caret move, no commit, no close', () {
        final combo = fruitBox(value: 'Banana')
          ..update(keyMsg('down'))
          ..update(keyMsg('down')); // cursor moved to Cherry, uncommitted

        final result = combo.update(pressOn('combo'));

        expect(result, isA<Handled>());
        expect(combo.isOpen, isTrue, reason: 'a bare-scope press never closes the popup');
        expect(combo.value, equals('Banana'), reason: 'a bare-scope press never commits');
        expect(combo.field.value, equals('Banana'), reason: 'no field text changes from a bare-scope press');
      });

      test('hover follows the pointer on the popup rows', () {
        final combo = fruitBox()..update(keyMsg('down'));

        combo.update(onList(combo, PointerAction.move, row: 2));

        expect(combo.internalList.hoverRow, equals(2));
      });

      test('a leave addressed to the popup list clears its hover', () {
        final combo = fruitBox()..update(keyMsg('down'));
        combo.update(onList(combo, PointerAction.move, row: 2));
        expect(combo.internalList.hoverRow, equals(2));

        final leaf = HitTag.join(combo.id, combo.internalList.id);
        final result = combo.update(PointerLeaveMsg(leaf));

        expect(result, isA<Handled>());
        expect(combo.internalList.hoverRow, isNull);
      });

      test('a wheel over the popup scrolls it without committing or closing', () {
        final combo = fruitBox(options: List.generate(10, (i) => 'item$i'))
          ..update(keyMsg('down'))
          ..internalList.viewport(rows: 3);

        final result = combo.update(onList(combo, PointerAction.wheelDown));

        expect(result, isA<Handled>());
        expect(combo.internalList.scrollOffset, greaterThan(0));
        expect(combo.isOpen, isTrue);
        expect(combo.value, isNull);
      });

      test('a wheel that would move nothing declines, so it can bubble', () {
        final combo = fruitBox()..update(keyMsg('down')); // already at the top

        final result = combo.update(onList(combo, PointerAction.wheelUp));

        expect(result, isA<Declined>());
      });
    });

    group('remote options', () {
      ComboboxModel<String> remoteBox({String? value, bool focused = true}) => ComboboxModel<String>(
        id: 'combo',
        fieldId: 'combo-field',
        toggleId: 'combo-toggle',
        label: (s) => s,
        value: value,
        focused: focused,
      );

      test('a combobox constructed without options is remote', () {
        expect(remoteBox().isRemote, isTrue);
        expect(fruitBox().isRemote, isFalse);
      });

      test('a text-editing key while closed opens and asks a query for the typed text', () {
        final combo = remoteBox();
        final result = combo.update(charMsg('a'));

        expect(combo.isOpen, isTrue);
        final cmd = (result as Handled).cmd! as LoadRequest;
        expect(cmd.id, equals('combo'));
        expect(cmd.key, equals(const QueryKey('a')));
        expect(combo.queryStatus, SliceStatus.filling);
      });

      test('down while closed opens and asks the empty query', () {
        final combo = remoteBox();
        final result = combo.update(keyMsg('down'));

        expect(combo.isOpen, isTrue);
        final cmd = (result as Handled).cmd! as LoadRequest;
        expect(cmd.key, equals(const QueryKey('')));
      });

      test('a toggle press while closed asks the empty query', () {
        final combo = remoteBox();
        final result = combo.update(pressOn('combo-toggle'));

        expect(combo.isOpen, isTrue);
        final cmd = (result as Handled).cmd! as LoadRequest;
        expect(cmd.key, equals(const QueryKey('')));
      });

      test('further typing asks a new query for the newest text', () {
        final combo = remoteBox()..update(charMsg('a'));
        final result = combo.update(charMsg('p'));

        final cmd = (result as Handled).cmd! as LoadRequest;
        expect(cmd.key, equals(const QueryKey('ap')));
      });

      test('an installing answer replaces the options wholesale, cursor on the first row', () {
        final combo = remoteBox()
          ..update(charMsg('a'))
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), data: ['Apple', 'Avocado']));

        expect(
          combo.queryStatus,
          SliceStatus.ready,
          reason: 'the loading row disappears once the newest query installs',
        );
        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals('Apple'));
      });

      test("an unedited open's answer places the cursor on the current value's row", () {
        final stored = RemoteOption(2, 'Banana');
        final combo = ComboboxModel<RemoteOption>(
          id: 'combo',
          fieldId: 'combo-field',
          toggleId: 'combo-toggle',
          label: (o) => o.name,
          value: stored,
          focused: true,
        )..update(keyMsg('down')); // opens without editing, asks QueryKey('')

        // The answer carries a fresh instance of the value, as a fetch would.
        final fetched = [RemoteOption(1, 'Apple'), RemoteOption(2, 'Banana'), RemoteOption(3, 'Cherry')];
        expect(identical(fetched[1], stored), isFalse, reason: 'the match must run on ==, not identity');
        combo.update(LoadResult<List<RemoteOption>>('combo', key: const QueryKey(''), data: fetched));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals(stored), reason: 'the cursor opened on the value, not the first row');
      });

      test("a typed query's answer keeps the cursor on the first row, even when the value appears", () {
        final combo = remoteBox(value: 'Banana')
          ..update(charMsg('a'))
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), data: ['Apple', 'Banana']));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals('Apple'), reason: 'an edited query installs with the cursor on the first match');
      });

      test('an out-of-order answer: the stale one drops, the newest installs', () {
        final combo = remoteBox()
          ..update(charMsg('a')) // asks QueryKey('a')
          ..update(charMsg('p')) // asks QueryKey('ap'), now the newest
          // The answer to 'a' lands after 'ap' was asked — superseded, so it
          // resolves its own slot but installs nothing.
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), data: ['Apple', 'Avocado']));
        final staleCommit = combo.update(keyMsg('enter'));
        expect(
          staleCommit,
          isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
          reason: 'the superseded answer never installed, so there is still nothing to commit',
        );

        // The newest query's own answer lands and installs.
        combo.update(const LoadResult<List<String>>('combo', key: QueryKey('ap'), data: ['Apple']));
        final commit = combo.update(keyMsg('enter'));
        expect(commit, isA<Handled>().having((h) => h.cmd, 'cmd', isA<ComboboxSelectCmd>()));
        expect(combo.value, equals('Apple'));
      });

      test('a refusal leaves the popup stalled and empty', () {
        final combo = remoteBox()
          ..update(charMsg('a'))
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), data: ['Apple', 'Avocado']))
          ..update(charMsg('p')) // asks QueryKey('ap'), clearing the matches
          ..update(const LoadResult<List<String>>.cancelled('combo', key: QueryKey('ap')));

        expect(combo.queryStatus, SliceStatus.stalled);
        expect(combo.queryError, isNull, reason: 'a refusal is not a failure');
        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull), reason: 'nothing stands to commit');
      });

      test('an installed empty answer is ready, not stalled', () {
        final combo = remoteBox()
          ..update(charMsg('a'))
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), data: []));

        expect(combo.queryStatus, SliceStatus.ready);
      });

      test('an error for the newest query is recorded, and a later query clears its display', () {
        final combo = remoteBox()
          ..update(charMsg('a'))
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), error: 'boom'));

        expect(combo.queryStatus, SliceStatus.failed);
        expect(combo.queryError, equals('boom'));

        combo.update(charMsg('p')); // asks QueryKey('ap'), now the newest
        expect(combo.queryError, isNull, reason: 'ap has its own, still-idle-or-loading slot');
        expect(combo.queryStatus, SliceStatus.filling);
      });

      test("asking a new query drops the superseded query's failed slot", () {
        final combo = remoteBox()
          ..update(charMsg('a')) // asks QueryKey('a')
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), error: 'boom'))
          ..update(charMsg('p')); // asks QueryKey('ap'), superseding 'a'

        expect(
          combo.queryLoads.stateFor(const QueryKey('a')).status,
          equals(LoadStatus.idle),
          reason: 'a failed slot leaves with its supersession; only in-flight slots stay',
        );
        expect(combo.queryError, isNull);
      });

      test("a superseded query's late failure resolves its slot without keeping the error", () {
        final combo = remoteBox()
          ..update(charMsg('a')) // asks QueryKey('a')
          ..update(charMsg('p')) // asks QueryKey('ap'); 'a' is still in flight
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), error: 'boom'));

        expect(
          combo.queryLoads.stateFor(const QueryKey('a')).status,
          equals(LoadStatus.idle),
          reason: "no display ever reads a superseded key's error, so the slot just resolves",
        );
        expect(combo.queryError, isNull);
      });

      test('clear() while open re-asks the empty query, replacing a standing error', () {
        final combo = remoteBox()
          ..update(charMsg('z')) // opens, asks QueryKey('z')
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('z'), error: 'boom'));
        expect(combo.queryError, equals('boom'));

        final cmd = combo.clear();
        expect(cmd, isA<LoadRequest>().having((r) => r.key, 'key', equals(const QueryKey(''))));
        expect(combo.isOpen, isTrue);
        expect(combo.queryError, isNull);
        expect(combo.queryStatus, SliceStatus.filling);
      });

      test('clear() while closed asks nothing', () {
        final combo = remoteBox(value: 'Banana');

        expect(combo.clear(), isNull);
        expect(combo.value, isNull);
        expect(combo.field.value, isEmpty);
        expect(combo.queryStatus, SliceStatus.ready);
      });

      test("an error for a superseded key never surfaces — only the newest key's error does", () {
        final combo = remoteBox()
          ..update(charMsg('a')) // asks 'a'
          ..update(charMsg('p')) // asks 'ap', now the newest; 'a' is superseded
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), error: 'boom'));

        expect(combo.queryError, isNull, reason: 'the newest key is ap, not the superseded a');
        expect(combo.queryStatus, SliceStatus.filling, reason: 'ap is still in flight');
      });

      test('a wrong-shaped answer fails the newest query and installs nothing', () {
        final combo = remoteBox()
          ..update(charMsg('a'))
          ..update(const LoadResult<Object?>('combo', key: QueryKey('a'), data: 42));

        expect(combo.queryStatus, SliceStatus.failed);
        expect(combo.queryError, isA<PayloadMismatch>());
        expect(combo.queryLoads.isLoading(const QueryKey('a')), isFalse, reason: 'the slot resolved');
        expect(combo.internalList.cachedItemCount, equals(0), reason: 'a mismatch is not "No matches"');
      });

      test('a null payload on a successful answer is a mismatch', () {
        final combo = remoteBox()
          ..update(charMsg('a'))
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a')));

        expect(combo.queryStatus, SliceStatus.failed);
        expect(combo.queryError, isA<PayloadMismatch>());
        expect(combo.internalList.cachedItemCount, equals(0));
      });

      test('a result for a query never asked is dropped (staleness guard)', () {
        final combo = remoteBox()..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), data: ['Apple']));

        expect(combo.internalList.cachedItemCount, equals(0), reason: 'a stale result must not install');
      });

      test('a result for another id is declined and ignored', () {
        final combo = remoteBox()..update(charMsg('a'));
        final verdict = combo.update(const LoadResult<List<String>>('other', key: QueryKey('a'), data: ['Apple']));

        expect(verdict, isA<Declined>(), reason: 'a message addressed elsewhere is not one this combobox understands');
        expect(combo.queryStatus, SliceStatus.filling, reason: 'still waiting for its own result');
        expect(combo.internalList.cachedItemCount, equals(0));
      });

      test('every result addressed to the combobox is consumed, installed or not', () {
        final combo = remoteBox()..update(charMsg('a'));

        expect(
          combo.update(const LoadResult<List<String>>('combo', key: QueryKey('zzz'), data: ['x'])),
          isA<Handled>(),
          reason: "a query never asked is dropped, but the message was the combobox's own",
        );
        expect(
          combo.update(const LoadResult<List<String>>('combo', key: QueryKey('a'), data: ['Apple'])),
          isA<Handled>(),
        );
        expect(combo.update(const LoadResult<List<String>>('combo', key: 'not a query', data: ['x'])), isA<Handled>());
      });

      test('a result whose id names the popup list is forwarded to the list, ahead of the id guard', () {
        final combo = remoteBox();
        final list = combo.internalList;
        final req = list.loadFirstPage();
        expect(req.id, isNot(equals(combo.id)));

        final verdict = combo.update(LoadResult<List<String>>(req.id, key: req.key, data: const ['Apple', 'Avocado']));

        expect(verdict, isA<Handled>(), reason: 'the list installed the page; the combobox never applied the guard');
        expect(list.cachedItemCount, equals(2));
        expect(combo.queryStatus, SliceStatus.ready, reason: 'no combobox query slot was touched');
      });

      test('a viewport report addressed to the popup list by its scoped path reaches the list', () {
        final combo = fruitBox();
        final list = combo.internalList;

        final verdict = combo.update(ViewportChanged('combo/${list.id}', rows: 2));

        expect(verdict, isA<Handled>());
        expect(list.visibleCount, equals(2), reason: 'the list recognised its own id as the leaf of the path');
        expect(combo.update(ViewportChanged('combo/${list.id}', rows: 2)), isA<Handled>());
      });

      test('a result addressed to the popup list by its scoped path is installed by the list', () {
        final combo = remoteBox();
        final list = combo.internalList;
        final req = list.loadFirstPage();

        final verdict = combo.update(
          LoadResult<List<String>>('combo/${req.id}', key: req.key, data: const ['Apple', 'Avocado']),
        );

        expect(verdict, isA<Handled>());
        expect(list.cachedItemCount, equals(2), reason: "the path form the composite forwards is the list's own");
      });

      test('commit with no cursor row commits nothing', () {
        final combo = remoteBox()
          ..update(keyMsg('down')) // asks the empty query
          ..update(const LoadResult<List<String>>('combo', key: QueryKey(''), data: []));

        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
        expect(combo.value, isNull);
        expect(combo.isOpen, isTrue, reason: 'nothing was committed, so nothing closes');
      });

      test('a status row is never a cursor target: Enter commits nothing while the newest query is still loading', () {
        final combo = remoteBox()..update(keyMsg('down')); // asks the empty query, no answer yet

        expect(combo.queryStatus, SliceStatus.filling);
        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
        expect(combo.value, isNull);
      });

      test('asking a query clears the standing matches', () {
        final combo = remoteBox()
          ..update(charMsg('a'))
          ..update(const LoadResult<List<String>>('combo', key: QueryKey('a'), data: ['Apple', 'Avocado']))
          ..update(charMsg('p')); // asks 'ap'; the popup now shows only its state

        expect(combo.queryStatus, SliceStatus.filling);
        final result = combo.update(keyMsg('enter'));
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull), reason: 'the stale matches are gone');
      });
    });

    group('PopupPlaced report', () {
      final area = Rect.create(x: 0, y: 0, width: 10, height: 6);
      final below = PopupPlacement(side: PopupSide.below, height: 3, decidedAgainst: area);

      test('stores the placement for the next paint while open', () {
        final combo = fruitBox()..update(keyMsg('down'));

        final result = combo.update(PopupPlaced(combo.id, below));

        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
        expect(combo.placement, below);
      });

      test('is handled whether or not the combobox is focused', () {
        final combo = fruitBox()..update(keyMsg('down'));
        combo
          ..focused =
              false // closes and clears
          ..update(pressOn(HitTag.join(combo.id, combo.toggleId))); // reopens unfocused

        expect(combo.isOpen, isTrue);
        expect(combo.update(PopupPlaced(combo.id, below)), isA<Handled>());
        expect(combo.placement, below);
      });

      test('a report landing after the popup closed is consumed and dropped', () {
        final combo = fruitBox()
          ..update(keyMsg('down'))
          ..update(keyMsg('escape'));

        final result = combo.update(PopupPlaced(combo.id, below));

        expect(result, isA<Handled>());
        expect(combo.placement, isNull, reason: 'close cleared the decision; the next open decides afresh');
      });

      test('a report addressed to another id is declined', () {
        final combo = fruitBox()..update(keyMsg('down'));

        expect(combo.update(PopupPlaced('other', below)), isA<Declined>());
        expect(combo.placement, isNull);
      });

      test("a report carrying the id as a path leaf is the combobox's own", () {
        final combo = fruitBox()..update(keyMsg('down'));

        expect(combo.update(PopupPlaced('form/combo', below)), isA<Handled>());
        expect(combo.placement, below);
      });
    });

    group('unfocused', () {
      test('declines a key', () {
        expect(fruitBox(focused: false).update(keyMsg('down')), isA<Declined>());
      });
    });

    group('unknown messages', () {
      test('declines a message it does not know', () {
        expect(fruitBox().update(const _UnknownMsg()), isA<Declined>());
      });

      test('declines a pointer leave and a pointer cancel', () {
        final combo = fruitBox();
        expect(combo.update(const PointerLeaveMsg('combo-field')), isA<Declined>());
        expect(combo.update(const PointerCancelMsg('combo-field')), isA<Declined>());
      });
    });
  });
}
