import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// A pointer over a 10×3 radio group at the origin, addressed to `'rg'`.
///
/// `local` doubles as the in-group position, so an [x] past the 10-cell
/// width or a [y] past the 3-cell height models a captured release slid off
/// the group.
PointerMsg pointerAt(PointerAction action, {Region? region, int x = 0, int y = 0}) => PointerMsg(
  global: Position(x, y),
  action: action,
  local: Position(x, y),
  targetId: 'rg',
  targetRect: Rect.create(x: 0, y: 0, width: 10, height: 3),
  region: region,
);

/// Three plain, enabled options: `'a'`, `'b'`, `'c'`.
List<RadioOption<String>> _abc() => [
  RadioOption(value: 'a', label: Line('A')),
  RadioOption(value: 'b', label: Line('B')),
  RadioOption(value: 'c', label: Line('C')),
];

void main() {
  group('RadioGroupModel construction', () {
    test('default state', () {
      final group = RadioGroupModel<String>(options: _abc());
      expect(group.id, startsWith('radio-'));
      expect(group.value, isNull);
      expect(group.disabled, isFalse);
      expect(group.error, isFalse);
      expect(group.focused, isFalse);
      expect(group.labelFirst, isFalse);
      expect(group.labelAlign, equals(TextAlign.start));
      expect(group.direction, equals(Axis.vertical));
      expect(group.glyphs, equals(CheckGlyphs.paren));
      expect(group.pressedIndex, isNull);
      expect(group.hoveredIndex, isNull);
    });

    test('cursor starts on the option matching value', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'b');
      expect(group.cursor, equals(1));
    });

    test('cursor starts on the first enabled option when value is null and option 0 is disabled', () {
      final options = [
        RadioOption(value: 'a', label: Line('A'), disabled: true),
        RadioOption(value: 'b', label: Line('B')),
        RadioOption(value: 'c', label: Line('C')),
      ];
      final group = RadioGroupModel<String>(id: 'rg', options: options);
      expect(group.cursor, equals(1));
      expect(group.value, isNull);
    });

    test('cursor starts at 0 when every option is disabled', () {
      final options = [
        RadioOption(value: 'a', label: Line('A'), disabled: true),
        RadioOption(value: 'b', label: Line('B'), disabled: true),
      ];
      final group = RadioGroupModel<String>(id: 'rg', options: options);
      expect(group.cursor, equals(0));
    });

    test('cursor starts at 0 on an empty list', () {
      final group = RadioGroupModel<String>(id: 'rg', options: const []);
      expect(group.cursor, equals(0));
    });
  });

  group('RadioGroupModel.value setter', () {
    test('moves the cursor and is silent', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc())..value = 'b';
      expect(group.value, equals('b'));
      expect(group.cursor, equals(1));
    });

    test('an unmatched value leaves the cursor', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc())..value = 'z';
      expect(group.value, equals('z'));
      expect(group.cursor, equals(0));
    });
  });

  group('RadioGroupModel.options setter', () {
    test('keeps a still-matching value and moves the cursor to it', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'b')
        ..options = [
          RadioOption(value: 'z', label: Line('Z')),
          RadioOption(value: 'b', label: Line('B')),
          RadioOption(value: 'a', label: Line('A')),
        ];
      expect(group.value, equals('b'));
      expect(group.cursor, equals(1));
    });

    test('an unmatched value clamps and seeks past a disabled option', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'a');
      expect(group.cursor, equals(0));
      group.options = [
        RadioOption(value: 'x', label: Line('X'), disabled: true),
        RadioOption(value: 'y', label: Line('Y')),
      ];
      expect(group.value, equals('a'), reason: 'the write itself does not touch an unmatched value');
      expect(group.cursor, equals(1));
    });

    test('a shorter list clamps the cursor', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'c');
      expect(group.cursor, equals(2));
      group.options = [RadioOption(value: 'x', label: Line('X'))];
      expect(group.cursor, equals(0));
    });

    test('an all-disabled replacement keeps the clamped index', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'c');
      expect(group.cursor, equals(2));
      group.options = [
        RadioOption(value: 'x', label: Line('X'), disabled: true),
        RadioOption(value: 'y', label: Line('Y'), disabled: true),
      ];
      // Cursor 2 clamps into the new 2-option list at index 1; every option
      // is disabled, so the seek finds nothing and the clamped index stays.
      expect(group.cursor, equals(1));
    });

    test('stores the list as given', () {
      final group = RadioGroupModel<String>(id: 'rg', options: const []);
      final newOptions = [RadioOption(value: 'a', label: Line('A'))];
      group.options = newOptions;
      expect(identical(group.options, newOptions), isTrue);
    });
  });

  group('RadioGroupModel.update key', () {
    test('down from the last option wraps to the first', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'c', focused: true);
      final result = group.update(const KeyMsg('down'));
      expect(group.cursor, equals(0));
      expect(group.value, equals('a'));
      expect(result, isA<Handled>().having((h) => h.events, 'events', [const RadioChangeEvent('rg', 'a')]));
    });

    test('up and down skip a disabled option', () {
      final withDisabled = [
        RadioOption(value: 'a', label: Line('A')),
        RadioOption(value: 'b', label: Line('B'), disabled: true),
        RadioOption(value: 'c', label: Line('C')),
      ];
      final group = RadioGroupModel<String>(id: 'rg', options: withDisabled, value: 'a', focused: true)
        ..update(const KeyMsg('down'));
      expect(group.value, equals('c'));

      group.update(const KeyMsg('up'));
      expect(group.value, equals('a'));
    });

    test('every arrow emits the new value', () {
      for (final key in ['up', 'down']) {
        final group = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'b', focused: true);
        final result = group.update(KeyMsg(key));
        expect(result, isA<Handled>().having((h) => h.events, 'events', hasLength(1)), reason: key);
      }
    });

    test('left, right, j and k bind to previous and next', () {
      final left = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'b', focused: true)
        ..update(const KeyMsg('left'));
      expect(left.value, equals('a'));

      final right = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'b', focused: true)
        ..update(const KeyMsg('right'));
      expect(right.value, equals('c'));

      final k = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'b', focused: true)
        ..update(const KeyMsg('k'));
      expect(k.value, equals('a'));

      final j = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'b', focused: true)
        ..update(const KeyMsg('j'));
      expect(j.value, equals('c'));
    });

    test('space on an unchosen group emits the cursor value', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), focused: true);
      final result = group.update(const KeyMsg('space'));
      expect(group.value, equals('a'));
      expect(result, isA<Handled>().having((h) => h.events, 'events', [const RadioChangeEvent('rg', 'a')]));
    });

    test('space on the chosen option is silent', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'a', focused: true);
      final result = group.update(const KeyMsg('space'));
      expect(result, isA<Handled>().having((h) => h.events, 'events', isEmpty));
    });

    test('space on a disabled cursor option is consumed and silent', () {
      final group =
          RadioGroupModel<String>(
              id: 'rg',
              options: [
                RadioOption(value: 'a', label: Line('A')),
                RadioOption(value: 'b', label: Line('B')),
              ],
              value: 'a',
              focused: true,
            )
            // Replacing options keeps the still-matching value, and its option
            // is now disabled — the cursor rests there, not on an enabled one.
            ..options = [
              RadioOption(value: 'a', label: Line('A'), disabled: true),
              RadioOption(value: 'b', label: Line('B')),
            ];
      expect(group.cursor, equals(0));

      final result = group.update(const KeyMsg('space'));
      expect(result, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.value, equals('a'));
    });

    test('enter declines', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), focused: true);
      expect(group.update(const KeyMsg('enter')), isA<Declined>());
    });

    test('unfocused declines', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc());
      expect(group.update(const KeyMsg('space')), isA<Declined>());
    });

    test('disabled consumes silently', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), focused: true, disabled: true);
      final result = group.update(const KeyMsg('space'));
      expect(result, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.value, isNull);
    });

    test('an empty group consumes every action', () {
      final group = RadioGroupModel<String>(id: 'rg', options: const [], focused: true);
      for (final key in ['up', 'down', 'space']) {
        final result = group.update(KeyMsg(key));
        expect(result, isA<Handled>().having((h) => h.events, 'events', isEmpty), reason: key);
      }
    });

    test('an all-disabled group consumes every action and keeps its cursor', () {
      final allDisabled = [
        RadioOption(value: 'a', label: Line('A'), disabled: true),
        RadioOption(value: 'b', label: Line('B'), disabled: true),
      ];
      final group = RadioGroupModel<String>(id: 'rg', options: allDisabled, focused: true);
      expect(group.cursor, equals(0));

      for (final key in ['up', 'down', 'space']) {
        final result = group.update(KeyMsg(key));
        expect(result, isA<Handled>().having((h) => h.events, 'events', isEmpty), reason: key);
        expect(group.cursor, equals(0), reason: key);
      }
    });
  });

  group('RadioGroupModel.update pointer', () {
    test('down and up on RowRegion(1) chooses option 1 and emits', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc());

      final down = group.update(pointerAt(PointerAction.down, region: const RowRegion(1)));
      expect(down, isA<Handled>().having((h) => h.events, 'events', isEmpty));

      final up = group.update(pointerAt(PointerAction.up, region: const RowRegion(1)));
      expect(up, isA<Handled>().having((h) => h.events, 'events', [const RadioChangeEvent('rg', 'b')]));
      expect(group.value, equals('b'));
    });

    test('up on another row than the down does not choose', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc())
        ..update(pointerAt(PointerAction.down, region: const RowRegion(0)));

      final up = group.update(pointerAt(PointerAction.up, region: const RowRegion(1)));
      expect(up, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.value, isNull);
    });

    test('up outside does not choose', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc())
        ..update(pointerAt(PointerAction.down, region: const RowRegion(0)));

      final up = group.update(pointerAt(PointerAction.up, region: const RowRegion(0), x: 20));
      expect(up, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.value, isNull);
    });

    test('a click on the chosen option is silent', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), value: 'a')
        ..update(pointerAt(PointerAction.down, region: const RowRegion(0)));

      final up = group.update(pointerAt(PointerAction.up, region: const RowRegion(0)));
      expect(up, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.value, equals('a'));
    });

    test('a click on a disabled option is consumed and does nothing', () {
      final withDisabled = [
        RadioOption(value: 'a', label: Line('A')),
        RadioOption(value: 'b', label: Line('B'), disabled: true),
      ];
      final group = RadioGroupModel<String>(id: 'rg', options: withDisabled);

      final down = group.update(pointerAt(PointerAction.down, region: const RowRegion(1)));
      expect(down, isA<Handled>().having((h) => h.events, 'events', isEmpty));

      final up = group.update(pointerAt(PointerAction.up, region: const RowRegion(1)));
      expect(up, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.value, isNull);
    });

    test('down with no region is consumed and starts nothing', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc());

      final down = group.update(pointerAt(PointerAction.down));
      expect(down, isA<Handled>().having((h) => h.events, 'events', isEmpty));

      final up = group.update(pointerAt(PointerAction.up, region: const RowRegion(0)));
      expect(up, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.value, isNull);
    });

    test('a move sets hoveredIndex', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc())
        ..update(pointerAt(PointerAction.move, region: const RowRegion(2)));
      expect(group.hoveredIndex, equals(2));
    });

    test('a move over a disabled option clears hoveredIndex', () {
      final withDisabled = [
        RadioOption(value: 'a', label: Line('A')),
        RadioOption(value: 'b', label: Line('B'), disabled: true),
      ];
      final group = RadioGroupModel<String>(id: 'rg', options: withDisabled)
        ..hoveredIndex = 0
        ..update(pointerAt(PointerAction.move, region: const RowRegion(1)));
      expect(group.hoveredIndex, isNull);
    });

    test('a move with no region clears hoveredIndex', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc())
        ..hoveredIndex = 0
        ..update(pointerAt(PointerAction.move));
      expect(group.hoveredIndex, isNull);
    });

    test('a leave clears hoveredIndex', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc())
        ..hoveredIndex = 0
        ..update(const PointerLeaveMsg('rg'));
      expect(group.hoveredIndex, isNull);
    });

    test('cancel ends the press', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc())
        ..update(pointerAt(PointerAction.down, region: const RowRegion(0)));
      expect(group.pressedIndex, equals(0));

      group.update(const PointerCancelMsg('rg'));
      expect(group.pressedIndex, isNull);

      final up = group.update(pointerAt(PointerAction.up, region: const RowRegion(0)));
      expect(up, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.value, isNull);
    });

    test('the wheel declines', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc());
      expect(group.update(pointerAt(PointerAction.wheelDown)), isA<Declined>());
      expect(group.update(pointerAt(PointerAction.wheelUp)), isA<Declined>());
    });

    test('a disabled group consumes and never hovers', () {
      final group = RadioGroupModel<String>(id: 'rg', options: _abc(), disabled: true);

      final down = group.update(pointerAt(PointerAction.down, region: const RowRegion(0)));
      expect(down, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.pressedIndex, isNull);

      final move = group.update(pointerAt(PointerAction.move, region: const RowRegion(0)));
      expect(move, isA<Handled>().having((h) => h.events, 'events', isEmpty));
      expect(group.hoveredIndex, isNull);
    });
  });

  group('RadioGroupModel.width', () {
    test('vertical is the widest row', () {
      final group = RadioGroupModel<String>(
        id: 'rg',
        options: [
          RadioOption(value: 'a', label: Line('A')),
          RadioOption(value: 'b', label: Line('Longer label')),
        ],
      );
      // Row 0: box '( )' (3) + gap (1) + label (1) = 5.
      // Row 1: box '( )' (3) + gap (1) + label (12) = 16, the widest.
      expect(group.width(const TermUnicodeMeasurer()), equals(16));
    });

    test('horizontal is the sum of the rows plus two cells per gap', () {
      final group = RadioGroupModel<String>(id: 'rg', direction: Axis.horizontal, options: _abc());
      // Three rows of '( ) A' (5 cells) each, plus two 2-cell gaps between them.
      expect(group.width(const TermUnicodeMeasurer()), equals(5 * 3 + 2 * 2));
    });

    test('empty is 0', () {
      final group = RadioGroupModel<String>(id: 'rg', options: const []);
      expect(group.width(const TermUnicodeMeasurer()), equals(0));
    });

    test('paren: a 3-cell box', () {
      final group = RadioGroupModel<String>(
        id: 'rg',
        options: [RadioOption(value: 'a', label: Line('Remember me'))],
      );
      // box '( )' (3) + gap (1) + label (11) = 15
      expect(group.width(const TermUnicodeMeasurer()), equals(15));
    });

    test('circle: a 1-cell box', () {
      final group = RadioGroupModel<String>(
        id: 'rg',
        options: [RadioOption(value: 'a', label: Line('Remember me'))],
        glyphs: CheckGlyphs.circle,
      );
      // box '◌' (1) + gap (1) + label (11) = 13
      expect(group.width(const TermUnicodeMeasurer()), equals(13));
    });

    test('orb: a 2-cell box', () {
      final group = RadioGroupModel<String>(
        id: 'rg',
        options: [RadioOption(value: 'a', label: Line('Remember me'))],
        glyphs: CheckGlyphs.orb,
      );
      // box '⚪' (2) + gap (1) + label (11) = 14
      expect(group.width(const TermUnicodeMeasurer()), equals(14));
    });
  });
}
