// Pins the keyboard portability invariant: the same user action must turn
// into the same app-visible messages whether the terminal is a plain one or
// a kitty-enhanced one, at every level of enhancement a real terminal might
// implement. Enhancement is only allowed to add fidelity — repeat marking,
// release events, exact typed text, layout-independent bindings — never to
// change what a naive `case KeyMsg(key: 'q')` or "insert `msg.text`" sees.
//
// Each row below is one physical action (a keystroke, a held key, a bare
// modifier tap). Its bytes are written out by hand for every protocol level,
// the way a real terminal would actually send them — not derived from the
// parser under test — so this suite catches drift in either termparser's
// encoding or kiko_core's `eventToMsg`. The exact escape sequences are cross-
// checked against termparser's own parser_test.dart corpus rather than
// guessed.
//
// The five levels are cumulative kitty keyboard-enhancement flag sets:
//
//   1. legacy                                     — no enhancement at all.
//   2. disambiguate                                — flag 1 only.
//   3. +eventTypes                                 — flags 1+2.
//   4. +alternateKeys +reportAllKeysAsEscapeCodes  — flags 1+2+4+8.
//   5. full                                        — flags 1+2+4+8+16.
//
// Column 4 folds two flags together on purpose. The task this matrix pins
// only names "alternate keys" for that column, but flag 4 (report alternate
// keys) never appears on the wire unless flag 8 (report all keys as escape
// codes) is also active — without flag 8, an ordinary letter or digit still
// arrives as a plain UTF-8 byte, and the alternate-key field would never be
// exercised. So column 4 is "flags 1+2+4+8": the first level at which a
// plain letter is forced into a CSI-u escape sequence.
//
// A key fact that shapes several rows: a terminal does NOT switch a
// text-producing key (a plain letter, or a letter with only shift or
// CapsLock held) to CSI-u just because disambiguate or reportEventTypes is
// on. It keeps sending plain UTF-8 text for those until reportAllKeysAsEscapeCodes
// (flag 8) forces every key, including plain text, through CSI-u. That is
// why columns 2 and 3 are byte-for-byte identical to column 1 for most rows.

import 'dart:convert';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser.dart';
import 'package:test/test.dart';

/// Bytes a terminal sends for [seq], with 'π' standing in for ESC (0x1b) —
/// the same convention termparser's own parser_test.dart uses, so an escape
/// sequence here reads the way it would in that corpus.
List<int> _esc(String seq) => utf8.encode(seq.replaceAll('π', '\x1b'));

/// Feeds raw terminal bytes through the real termparser parser and then
/// through `eventToMsg`, collecting whatever reaches `update` — the same
/// two-stage pipeline the runtime itself runs. Events `eventToMsg` drops
/// (a bare modifier's auto-repeat) are simply absent from the result.
List<Msg> messagesFor(List<int> bytes) {
  final parser = Parser()..advance(bytes);
  final msgs = <Msg>[];
  for (final event in parser.drainEvents()) {
    final msg = eventToMsg(event);
    if (msg != null) msgs.add(msg);
  }
  return msgs;
}

/// Names of the five columns, in the order every row's cell list follows.
const _levelNames = [
  'legacy',
  'disambiguate',
  '+eventTypes',
  '+alternateKeys +reportAllKeysAsEscapeCodes',
  'full',
];

/// One protocol level's script for a row: the bytes a terminal sends, and
/// the exact messages they must produce.
class _Cell {
  const _Cell(this.bytes, this.expected);

  /// The raw bytes a terminal at this level sends for the row's action.
  final List<int> bytes;

  /// The messages `messagesFor` must return for [bytes].
  final List<Msg> expected;
}

/// One user action, scripted across the five protocol levels.
///
/// A `null` entry means the action has no wire encoding at that level — nothing
/// to send, so nothing to compare (see the bare-modifier-tap and Cyrillic
/// ctrl rows below).
class _Row {
  const _Row(this.name, this.byLevel, {this.checkIdentity = true});

  /// Describes the action; doubles as the test name.
  final String name;

  /// One cell per level, aligned with [_levelNames]; null where the row has
  /// no script at that level.
  final List<_Cell?> byLevel;

  /// Whether the sequence of `KeyMsg.key` values must be identical across
  /// every level this row scripts — the portability invariant in its literal
  /// form. True for almost every row. The caps-lock row sets this false and
  /// explains why in its own comment: that row is a genuine, protocol-level
  /// exception, not a test gap.
  final bool checkIdentity;
}

final _rows = [
  // A plain letter has nothing for any enhancement flag to change: no
  // modifier, no lock state, no repeat, no release. Same key and same text
  // at every level.
  _Row('plain letter "a" (press once)', [
    const _Cell([0x61], [KeyMsg('a', text: 'a')]), // legacy: the byte 'a'
    const _Cell([0x61], [KeyMsg('a', text: 'a')]), // disambiguate: still plain text
    const _Cell([0x61], [KeyMsg('a', text: 'a')]), // +eventTypes: still plain text
    _Cell(_esc('π[97u'), const [KeyMsg('a', text: 'a')]), // forced to CSI-u, no mods to report
    _Cell(_esc('π[97;1;97u'), const [KeyMsg('a', text: 'a')]), // + associated text
  ]),

  // Shift+A: a plain terminal can only ever send the produced character 'A'
  // — it has no way to distinguish "shift held" from "just a capital letter
  // was typed". Shift alone does not force CSI-u either (disambiguate and
  // reportEventTypes only escalate keys that have OTHER modifiers, or that
  // would otherwise be ambiguous), so columns 1-3 are the same plain byte.
  // At column 4 the alternate-key field reports the shifted character
  // directly, so toSpec() folds it into 'A' and text follows the same
  // substituted character — key and text agree at every level.
  _Row('capital: Shift+A (press once)', [
    const _Cell([0x41], [KeyMsg('A', text: 'A')]), // legacy: the byte 'A'
    const _Cell([0x41], [KeyMsg('A', text: 'A')]), // disambiguate: still plain text
    const _Cell([0x41], [KeyMsg('A', text: 'A')]), // +eventTypes: still plain text
    _Cell(_esc('π[97:65;2u'), const [KeyMsg('A', text: 'A')]), // base 'a', shifted-key 'A', mod=shift
    _Cell(_esc('π[97:65;2;65u'), const [KeyMsg('A', text: 'A')]), // + associated text 'A'
  ]),

  // Shift+1 on a US layout types '!'. Same reasoning as Shift+A: shift alone
  // never forces CSI-u, so columns 1-3 are the plain '!' byte. At column 4,
  // the alternate-key field carries '!' directly (base '1', shifted '!'),
  // and toSpec()'s shift-folding rule applies to ANY character the parser
  // confirms shift produced, not just letters — so key folds to '!' there
  // too. Key is '!' at every level; see the one-off case further down for
  // what happens to this same keystroke when the terminal does NOT report
  // alternate keys.
  _Row('shifted symbol: Shift+1 (US: types "!")', [
    const _Cell([0x21], [KeyMsg('!', text: '!')]), // legacy: the byte '!'
    const _Cell([0x21], [KeyMsg('!', text: '!')]), // disambiguate: still plain text
    const _Cell([0x21], [KeyMsg('!', text: '!')]), // +eventTypes: still plain text
    _Cell(_esc('π[49:33;2u'), const [KeyMsg('!', text: '!')]), // base '1', shifted-key '!'
    _Cell(_esc('π[49:33;2;33u'), const [KeyMsg('!', text: '!')]), // + associated text '!'
  ]),

  // Ctrl+A: legacy sends the control byte 0x01, no way around it. Ctrl is
  // exactly the kind of modifier disambiguate exists to disambiguate, so
  // every enhanced level sends CSI-u from column 2 onward — reportEventTypes
  // and reportAllKeysAsEscapeCodes/alternateKeys don't change a bare ctrl
  // press's wire form (no shift, so no alternate-key field applies; a single
  // press needs no explicit event-type subparam). Ctrl+letter never types
  // text, at any level.
  _Row('ctrl chord: ctrl+a', [
    const _Cell([0x01], [KeyMsg('ctrl+a')]), // legacy: control byte 0x01
    _Cell(_esc('π[97;5u'), const [KeyMsg('ctrl+a')]), // disambiguate: CSI-u, mod=ctrl
    _Cell(_esc('π[97;5u'), const [KeyMsg('ctrl+a')]), // +eventTypes: same wire form
    _Cell(_esc('π[97;5u'), const [KeyMsg('ctrl+a')]), // +alternateKeys: no alt-key field applies
    _Cell(_esc('π[97;5u'), const [KeyMsg('ctrl+a')]), // full: still no text to report
  ]),

  // An arrow key was never ambiguous the way Escape or ctrl+letter were —
  // it has always had its own CSI final byte (A/B/C/D). None of the
  // enhancement flags change a bare, unmodified arrow's wire form, so this
  // row is the same bytes at every level: a real invariant, not a
  // coincidence of this matrix's column choices.
  _Row('named key: arrow up (press once)', [
    _Cell(_esc('π[A'), const [KeyMsg('up')]),
    _Cell(_esc('π[A'), const [KeyMsg('up')]),
    _Cell(_esc('π[A'), const [KeyMsg('up')]),
    _Cell(_esc('π[A'), const [KeyMsg('up')]),
    _Cell(_esc('π[A'), const [KeyMsg('up')]),
  ]),

  // Holding 'a' down. Legacy and disambiguate can only resend the plain byte
  // three times — a held key looks identical to three fast presses, and
  // there is no release either. From +eventTypes onward the terminal marks
  // the second and third keystrokes as repeats and, once the finger lifts,
  // sends a release — which arrives as KeyReleaseMsg, a sibling class a
  // `case KeyMsg()` can never match, so the KeyMsg count stays 3 everywhere
  // even though the raw event count grows to 4. At +alternateKeys
  // +reportAllKeysAsEscapeCodes even the FIRST press is forced to CSI-u
  // (flag 8 covers every key, not just repeats/releases). At full, press and
  // repeat carry the associated-text field; the release script below
  // deliberately includes a text parameter too, to prove it is dropped —
  // kitty never attaches text to a release, and csi_parser.dart enforces
  // that defensively.
  _Row('held key: three keystrokes of "a"', [
    _Cell(utf8.encode('aaa'), const [
      KeyMsg('a', text: 'a'),
      KeyMsg('a', text: 'a'),
      KeyMsg('a', text: 'a'),
    ]),
    _Cell(utf8.encode('aaa'), const [
      KeyMsg('a', text: 'a'),
      KeyMsg('a', text: 'a'),
      KeyMsg('a', text: 'a'),
    ]),
    _Cell(
      [
        0x61, // first press: still a plain byte, no event-type reporting needed for a first press
        ..._esc('π[97;1:2u'), // repeat
        ..._esc('π[97;1:2u'), // repeat
        ..._esc('π[97;1:3u'), // release
      ],
      const [
        KeyMsg('a', text: 'a'),
        KeyMsg.repeat('a', text: 'a'),
        KeyMsg.repeat('a', text: 'a'),
        KeyReleaseMsg('a'),
      ],
    ),
    _Cell(
      [
        ..._esc('π[97u'), // first press: now CSI-u too, flag 8 covers every key
        ..._esc('π[97;1:2u'),
        ..._esc('π[97;1:2u'),
        ..._esc('π[97;1:3u'),
      ],
      const [
        KeyMsg('a', text: 'a'),
        KeyMsg.repeat('a', text: 'a'),
        KeyMsg.repeat('a', text: 'a'),
        KeyReleaseMsg('a'),
      ],
    ),
    _Cell(
      [
        ..._esc('π[97;1;97u'), // press + associated text
        ..._esc('π[97;1:2;97u'), // repeat + associated text
        ..._esc('π[97;1:2;97u'),
        ..._esc('π[97;1:3;97u'), // release: text param present but must be dropped
      ],
      const [
        KeyMsg('a', text: 'a'),
        KeyMsg.repeat('a', text: 'a'),
        KeyMsg.repeat('a', text: 'a'),
        KeyReleaseMsg('a'),
      ],
    ),
  ]),

  // CapsLock engaged, press the 'a' key. This is the one row where the
  // portability invariant genuinely does not hold for `key`, not just for
  // `text` — and it is not a bug, it is what the two protocols actually let
  // a terminal say.
  //
  // Legacy has no concept of "the a key with a lock state" — it can only
  // send the character that was produced, which is the byte 'A'. The parser
  // has no way to tell that apart from an ordinary capital A, so key comes
  // out 'A', same as the Shift+A row.
  //
  // Kitty's protocol draws a sharp line legacy cannot: the unicode-key-code
  // it sends for a locked 'a' is 97 (the physical key), never 65 — CapsLock
  // rides a separate modifier bit (64) that termparser deliberately drops
  // rather than surface (see modifierParser), so the resulting KeyCode is
  // plain 'a' with no modifiers at all. toSpec() only folds a letter's case
  // when the shift modifier is actually set, and it is not here, so key
  // comes out 'a'. That makes key 'A' at columns 1-3 and 'a' at columns 4-5
  // for the exact same physical keystroke — a real divergence, not a
  // degraded corner of an otherwise-identical stream.
  //
  // Text tells the more forgiving half of the story. Without the
  // associated-text field (column 4) there is nothing to recover the
  // produced capital from, so text falls back to the base character: 'a'.
  // With it (column 5, full), the terminal reports the actual typed text
  // directly, and text is 'A' again — matching legacy.
  _Row(
    'caps-locked typing: CapsLock engaged, press "a"',
    [
      const _Cell([0x41], [KeyMsg('A', text: 'A')]), // legacy: the byte 'A'
      const _Cell([0x41], [KeyMsg('A', text: 'A')]), // disambiguate: still plain text
      const _Cell([0x41], [KeyMsg('A', text: 'A')]), // +eventTypes: still plain text
      _Cell(_esc('π[97;65u'), const [KeyMsg('a', text: 'a')]), // base key 'a', lock bit dropped, no text field
      _Cell(_esc('π[97;65;65u'), const [KeyMsg('a', text: 'A')]), // same base key, text field recovers 'A'
    ],
    checkIdentity: false, // see the row comment: key genuinely differs, by design of both protocols
  ),

  // Dead-key/option composition, e.g. Option+e then e on macOS, producing
  // 'é'. The OS resolves the composition before anything reaches the
  // terminal, so every level sees one keystroke, never two. Legacy and the
  // no-text-field enhanced columns can only report the precomposed
  // character (U+00E9, one code unit) as both key and text. The full level's
  // associated-text field is independent of the key, so this script gives it
  // the NFD-decomposed spelling of the same grapheme — 'e' (U+0065) plus a
  // combining acute accent (U+0301) — on purpose: two code units that render
  // identically to the precomposed form but are NOT the same Dart string.
  // kiko does no Unicode normalization anywhere in this path, so an editor
  // comparing `msg.text` byte-for-byte across levels would see this as a
  // different string even though the user typed the same key. Key stays 'é'
  // at every level; only text carries this NFC/NFD wrinkle, and only at the
  // one level that sources text from the protocol field instead of the base
  // character.
  _Row('dead-key/option composition: press produces "é"', [
    _Cell(utf8.encode('é'), const [KeyMsg('é', text: 'é')]), // legacy: precomposed 'é', 2 UTF-8 bytes
    _Cell(utf8.encode('é'), const [KeyMsg('é', text: 'é')]), // disambiguate: still plain text
    _Cell(utf8.encode('é'), const [KeyMsg('é', text: 'é')]), // +eventTypes: still plain text
    _Cell(_esc('π[233u'), const [KeyMsg('é', text: 'é')]), // CSI-u, no text field, falls back to base char
    _Cell(_esc('π[233;1;101:769u'), [
      const KeyMsg('é', text: 'é'), // NFD: 'e' + combining acute — canonically-equal, not string-equal
    ]),
  ]),

  // Tapping left Shift alone — no other key involved. A plain terminal
  // literally cannot report this: modifiers only ever ride on some other
  // key's byte, so there is nothing to send and nothing to parse. Once
  // reportEventTypes is active the tap becomes visible as a genuine
  // press/release pair on its own kitty functional code (57441); a repeat of
  // the held modifier carries no new information and is dropped at intake
  // (see eventToMsg), so three raw wire events collapse to two messages.
  // Neither reportAlternateKeys nor reportAllKeysAsEscapeCodes changes a
  // modifier key's own encoding, so columns 3-5 are identical.
  _Row('bare modifier tap: press + release of left Shift', [
    const _Cell([], []), // legacy: nothing to send
    const _Cell([], []), // disambiguate: still nothing to send
    _Cell(
      [
        ..._esc('π[57441u'), // press (self-modifier: leftShift implies shift)
        ..._esc('π[57441;1:2u'), // repeat: dropped, carries no message
        ..._esc('π[57441;1:3u'), // release
      ],
      const [
        ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true),
        ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: false),
      ],
    ),
    _Cell(
      [
        ..._esc('π[57441u'),
        ..._esc('π[57441;1:2u'),
        ..._esc('π[57441;1:3u'),
      ],
      const [
        ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true),
        ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: false),
      ],
    ),
    _Cell(
      [
        ..._esc('π[57441u'),
        ..._esc('π[57441;1:2u'),
        ..._esc('π[57441;1:3u'),
      ],
      const [
        ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: true),
        ModifierKeyMsg(ModifierKey.shift, ModifierSide.left, down: false),
      ],
    ),
  ]),

  // ctrl+я on a Cyrillic keyboard layout, physical position of the US 'z'
  // key. Legacy control-byte generation only has a defined mapping for the
  // ASCII range (0x01-0x1A/0x1C-0x1F) — there is no legacy byte for "ctrl
  // held while a non-ASCII character key is down", so this row has no
  // legacy cell at all (see the standalone comparison case right after this
  // row's test for what a Cyrillic layout's PLAIN keystrokes look like at
  // legacy). Ctrl forces CSI-u from disambiguate onward, same as ctrl+a.
  // The base-layout field only appears once reportAlternateKeys is
  // requested, which is why baseKey is null through column 3 and 'ctrl+z'
  // from column 4 on — matching termparser's own corpus test for this exact
  // sequence.
  _Row('baseKey: ctrl+я, base-layout key z', [
    null, // no legacy byte encoding for ctrl+non-ASCII — see standalone case below
    _Cell(_esc('π[1103;5u'), const [KeyMsg('ctrl+я')]), // disambiguate: no base-layout field yet
    _Cell(_esc('π[1103;5u'), const [KeyMsg('ctrl+я')]), // +eventTypes: same
    _Cell(_esc('π[1103::122;5u'), const [KeyMsg('ctrl+я', baseKey: 'ctrl+z')]),
    _Cell(_esc('π[1103::122;5u'), const [KeyMsg('ctrl+я', baseKey: 'ctrl+z')]),
  ]),
];

void main() {
  group('keyboard protocol invariant matrix', () {
    for (final row in _rows) {
      test(row.name, () {
        final actualKeySequencesPerLevel = <List<String>>[];

        for (var i = 0; i < row.byLevel.length; i++) {
          final cell = row.byLevel[i];
          if (cell == null) continue; // this action has no wire encoding at this level

          final actual = messagesFor(cell.bytes);
          expect(actual, equals(cell.expected), reason: '${row.name} @ ${_levelNames[i]}');

          if (row.checkIdentity) {
            actualKeySequencesPerLevel.add(actual.whereType<KeyMsg>().map((m) => m.key).toList());
          }
        }

        // The keystroke identity invariant: every level this row scripts
        // must agree on the sequence of KeyMsg.key values it produces. This
        // compares the parser's REAL output across levels, independent of
        // whatever we hand-wrote as `expected` above.
        if (row.checkIdentity) {
          for (final sequence in actualKeySequencesPerLevel.skip(1)) {
            expect(
              sequence,
              equals(actualKeySequencesPerLevel.first),
              reason: '${row.name}: KeyMsg.key must be identical at every level',
            );
          }
        }
      });
    }
  });

  group('one-off edge cases', () {
    // Companion to the Cyrillic baseKey row above: what a Cyrillic-layout
    // terminal's PLAIN keystrokes (no ctrl) look like at legacy, for
    // comparison. There is no base-layout information here at all — legacy
    // never has it, at any level — so this is its own standalone case
    // rather than a cell in that row's matrix.
    test('legacy on a Cyrillic layout: plain "я" has no ctrl, no baseKey', () {
      final actual = messagesFor(utf8.encode('я'));
      expect(actual, equals(const [KeyMsg('я', text: 'я')]));
    });

    // The written contract's degraded edge for shift-folding, spelled out:
    // "on a terminal that disambiguates escape codes but does not report
    // alternate keys, folding is best-effort — letters fold by case, shifted
    // symbols keep their explicit-modifier spec". Flags 1+2+8 (disambiguate
    // + eventTypes + reportAllKeysAsEscapeCodes) force Shift+1 into CSI-u
    // without ever requesting reportAlternateKeys (flag 4), so no alternate
    // key field ever arrives on the wire — this is not one of the five
    // columns above (which always pair flag 8 with flag 4), it is the
    // "partial support" terminal the contract's own text calls out. Without
    // the shifted-key field, toSpec() cannot know '1'+shift produces '!' on
    // this layout, so it keeps the explicit modifier: key is 'shift+1', not
    // '!'. Text degrades the same way, to the unshifted '1'.
    test('shift+1, disambiguate+eventTypes+reportAllKeysAsEscapeCodes but NOT alternateKeys', () {
      final actual = messagesFor(_esc('π[49;2u'));
      expect(actual, equals(const [KeyMsg('shift+1', text: '1')]));
    });

    // The same "no alternate keys" terminal, but with a cased LETTER instead
    // of a digit: key and text fold together. The event arrives as the base
    // char 'a' with the shift bit and no alternate-key substitution, and
    // both projections apply the same best-effort rule — a cased letter
    // folds by case, layout or not — so the keystroke reads
    // KeyMsg(key: 'A', text: 'A') and an editor inserting `msg.text` types
    // the right case even on this partial-support terminal.
    test('shift+A, same partial terminal — key and text fold together', () {
      final actual = messagesFor(_esc('π[97;2u'));
      expect(actual, equals(const [KeyMsg('A', text: 'A')]));
    });

    // Sanity check on the lock-bit handling itself, straight from
    // termparser's own corpus (modifier wire values 65 = CapsLock alone, 66 =
    // CapsLock+shift, 129 = NumLock alone): none of these lock bits ever
    // surface as 'shift' or 'ctrl' in the resulting key. The 66 case folds
    // text by shift the same as a real Shift — best-effort, since without a
    // text field the event cannot say that CapsLock+Shift+a actually types
    // 'a' (caps inverts shift for letters); a terminal reporting associated
    // text overrides this, as the CapsLock row above shows.
    test('lock bits never surface as modifiers in KeyMsg.key', () {
      expect(
        messagesFor(_esc('π[97;65u')), // CapsLock alone: bit dropped entirely, no modifiers at all
        equals(const [KeyMsg('a', text: 'a')]),
      );
      expect(
        messagesFor(_esc('π[97;66u')), // CapsLock+shift: shift survives, CapsLock bit dropped
        equals(const [KeyMsg('A', text: 'A')]),
      );
      expect(
        messagesFor(_esc('π[49;129u')), // NumLock alone: bit dropped entirely
        equals(const [KeyMsg('1', text: '1')]),
      );
    });

    // Rounds out the transition assertions with real parsed bytes rather
    // than hand-built KeyEvents: a release and a bare modifier both fail a
    // `case KeyMsg()` match, because they are siblings of KeyMsg under Msg,
    // never KeyMsg itself.
    test('a release and a bare modifier both fail a case KeyMsg() match', () {
      bool matchesKeyMsg(Msg msg) => switch (msg) {
        KeyMsg() => true,
        _ => false,
      };

      final release = messagesFor(_esc('π[97;1:3u')).single;
      final modifierDown = messagesFor(_esc('π[57441u')).single;

      expect(release, isA<KeyReleaseMsg>());
      expect(modifierDown, isA<ModifierKeyMsg>());
      expect(matchesKeyMsg(release), isFalse);
      expect(matchesKeyMsg(modifierDown), isFalse);
    });
  });
}
