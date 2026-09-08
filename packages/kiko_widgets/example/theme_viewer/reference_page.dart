import 'package:kiko/kiko.dart';

import 'shared.dart';

// Page 1: the tone tables, the intent strip, and the anatomy band. The page
// is static — nothing on it takes focus.

/// Page 1 of the theme viewer: the tone tables, the intent strip, and the
/// anatomy band.
///
/// The tone tables lay each theme out as its tones, grouped the way the
/// theme itself groups them (Intent / Neutral / Interaction), with every
/// tone's two halves and all three projections side by side. They read the
/// resolver's effective set, so under ANSI-16 they show the theme's
/// `tones16` table instead of its RGB tones.
View referencePage(Theme theme, StyleResolver resolver) {
  final t = resolver.tones;
  return Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      // The tone tables keep a fixed height; the intent strip and the
      // anatomy band take only the rows their content needs.
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
    ],
  );
}

// ── the intent strip ──

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
  final selectedFill = resolver.resolve(null, const {WidgetState.selected}, cls: PaintClass.fill);
  final cursorFill = resolver.resolve(null, const {WidgetState.cursor}, cls: PaintClass.fill);
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
        ('placeholder', mutedInk),
      ],
    ),
    (
      'ListView',
      [
        ('[item]', text),
        ('selectedItem', selectedFill),
        ('cursorItem', cursorFill),
        ('pending', mutedInk),
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
        ('pending', mutedInk),
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
        // Button has one anatomy slot, face. A null face derives the primary
        // fill; every other look rides the state matrix.
        Row(
          children: [
            col(11, Line('Button', style: mutedInk)),
            Line(' primary.fill face ', style: resolver.fill(t.primary)),
            const SizedBox(width: 1),
            Line('one slot, face; states ride the matrix', style: mutedInk),
          ],
        ),
      ],
    ),
  );
}

/// One anatomy row: the widget's name, then its slots as painted chips.
View _anatomyRow(StyleResolver resolver, String name, List<(String, Style)> slots) => Row(
  children: [
    col(11, Line(name, style: resolver.ink(resolver.tones.muted))),
    for (final (slot, style) in slots) ...[
      Line(' $slot ', style: style),
      const SizedBox(width: 1),
    ],
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
      col(11, Line('Tone', style: label)),
      col(8, Line('color', style: label)),
      col(8, Line('on', style: label)),
      col(4, Line('ink', style: label)),
      const SizedBox(width: 1),
      col(4, Line('fill', style: label)),
      const SizedBox(width: 1),
      col(4, Line('wash', style: label)),
    ],
  );
}

/// One tone: its name, its two halves as labels, then its three projections
/// — all through the resolver, so the row degrades with the render tier.
///
/// A chrome [Tone] has no `on` and cannot fill: both columns show "—" for
/// one, since only a [SurfaceTone] carries a readable foreground.
View _toneRow(StyleResolver resolver, String name, Tone tone) {
  final muted = resolver.ink(resolver.tones.muted);
  final defaultText = resolver.ink(Tone(color: resolver.tones.background.on));
  final on = tone is SurfaceTone ? tone.on : null;
  final fill = tone is SurfaceTone ? resolver.fill(tone) : const Style();
  return Row(
    children: [
      // Name, in the effective set's default text color.
      col(11, Line(name, style: defaultText)),
      // color half — drawn in its own hue (its ink) so the swatch reads true.
      col(8, Line(colorLabel(tone.color), style: tone.color != null ? resolver.ink(tone) : muted)),
      // on half — drawn in the on color, or muted "—" for a chrome tone.
      col(8, Line(colorLabel(on), style: on != null ? resolver.ink(Tone(color: on)) : muted)),
      // ink: fg only — tinted text over the theme background.
      swatch(4, resolver.ink(tone)),
      const SizedBox(width: 1),
      // fill: on over color — blank for a chrome tone, which has none.
      swatch(4, fill),
      const SizedBox(width: 1),
      // wash: bg only — default text sitting on the tint.
      swatch(4, defaultText.patch(resolver.wash(tone))),
    ],
  );
}
