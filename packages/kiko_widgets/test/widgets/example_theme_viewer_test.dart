import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

import '../../example/theme_viewer/main.dart' as viewer;

/// A frame over a fresh in-memory buffer, ready to render into.
Frame _testFrame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// The buffer as a string: one line per row, trailing blanks trimmed.
String _screenText(Buffer buffer) {
  final out = StringBuffer();
  final area = buffer.area;
  for (var y = area.top; y < area.bottom; y++) {
    final row = StringBuffer();
    for (var x = area.left; x < area.right; x++) {
      final cell = buffer[(x: x, y: y)];
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}

// The theme viewer example, rendered headlessly: it is the canonical example
// for the theming doctrine, so its first frame is where the lift-or-fallback
// rule (a cursor lifting a selected row's fill instead of replacing it)
// shows on a real app screen, not just in a resolver unit test.
void main() {
  test(
    "the gallery list's first row starts selected under the cursor, as the selection fill lifted once",
    () {
      final model = viewer.Model();
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 160, height: 50));
      final frame = Frame(buffer.area, buffer, 0);
      viewer.view(model, frame);

      // The list tags its own rect with the model id, so the row's cells
      // come straight from the hit map rather than hard-coded coordinates.
      final rect = frame.hits.rectOf(model.list.id);
      expect(rect, isNotNull, reason: 'the list paints under its own id');
      final cell = buffer[(x: rect!.x, y: rect.y)];

      expect(cell.fg, equals(Theme.dark.selection.on));
      expect(cell.bg, equals(Theme.dark.selection.color!.shiftLightness(Theme.step)));
      // The list starts unfocused — the name field holds focus first — so
      // the cursor paints in the wash class and adds no bold. Bold marks a
      // collection that owns focus.
      expect(cell.modifier.has(Modifier.bold), isFalse);
    },
  );

  test('the starting frame shows the checked mark, a selected table row under the crosshair, and the crosshair', () {
    final model = viewer.Model();
    final frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final buffer = frame.buffer;

    final box = frame.hits.rectOf(model.agree.id);
    expect(box, isNotNull, reason: 'the checkbox paints under its own id');
    expect(buffer[(x: box!.x + 1, y: box.y)].symbol, 'x', reason: 'seeded checked, so the mark shows');

    final radio = frame.hits.rectOf(model.delivery.id);
    expect(radio, isNotNull, reason: 'the radio group paints under its own id');
    final chosenRow = model.delivery.options.indexWhere((option) => option.value == model.delivery.value);
    final chosenMark = buffer[(x: radio!.x + 1, y: radio.y + chosenRow)];
    expect(chosenMark.symbol, '*', reason: 'seeded chosen, so the chosen option shows its mark');
    expect(chosenMark.fg, equals(Theme.dark.primary.color));

    expect(model.table.getSelectedKeys(), equals({'R001'}));
    final table = frame.hits.rectOf(model.table.id);
    expect(table, isNotNull, reason: 'the table paints under its own id');
    // The header takes the first row; the selected row sits under the
    // cursor, so the crosshair's row wash lifts the selection fill.
    final selected = buffer[(x: table!.x + 1, y: table.y + 1)];
    expect(selected.fg, equals(Theme.dark.selection.on));
    expect(selected.bg, equals(Theme.dark.selection.color!.shiftLightness(Theme.step)));
    // The cursor column runs down every row: a bare row below the cursor
    // carries the cursor wash in that column.
    expect(
      buffer[(x: table.x + 1, y: table.y + 2)].bg,
      equals(Theme.dark.background.color!.shiftLightness(Theme.step)),
    );
  });

  test('F4 cycles the header through the four pages', () {
    final model = viewer.Model();
    var frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final ctx = UpdateContext(hits: frame.hits, area: frame.area);

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 3/4: Contrast'));

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 4/4: States'));

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 1/4: Reference'));

    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 2/4: Gallery'));
  });

  test('the state strip paints each chip as one resolve call over its ground', () {
    final model = viewer.Model();
    final frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final buffer = frame.buffer;
    final resolver = StyleResolver(Theme.dark, policy: RenderPolicy.color);

    // "selected + cursor" resolves to the same fill on both grounds: the fill
    // row's base is bare, so the resolved style carries its own fg and bg and
    // never falls back to the ground underneath it. The chip proves the
    // resolve call, not the ground.
    final selCurRect = frame.hits.rectOf('strip/bg/fill/sel+cur');
    expect(selCurRect, isNotNull, reason: 'the sel+cur chip paints under its own tag');
    final selCurCell = buffer[(x: selCurRect!.x + 1, y: selCurRect.y)];
    final selCurStyle = resolver.resolve(
      null,
      const {WidgetState.selected, WidgetState.cursor},
      cls: PaintClass.fill,
    );
    expect(selCurCell.fg, equals(selCurStyle.fg));
    expect(selCurCell.bg, equals(selCurStyle.bg));
    expect(selCurCell.modifier.has(Modifier.bold), isFalse, reason: 'the cursor lifts without bold unless focused');

    // "rest" resolves to an untouched, bare style, so its cell shows whatever
    // ground the group painted underneath it — the one chip where the two
    // groups differ.
    final bgRestRect = frame.hits.rectOf('strip/bg/fill/rest');
    final sfRestRect = frame.hits.rectOf('strip/sf/fill/rest');
    expect(bgRestRect, isNotNull, reason: "the background group's rest chip paints under its own tag");
    expect(sfRestRect, isNotNull, reason: "the surface group's rest chip paints under its own tag");
    final bgRestBg = buffer[(x: bgRestRect!.x + 1, y: bgRestRect.y)].bg;
    final sfRestBg = buffer[(x: sfRestRect!.x + 1, y: sfRestRect.y)].bg;
    expect(bgRestBg, equals(Theme.dark.background.color));
    expect(sfRestBg, equals(Theme.dark.surface.color));
    expect(bgRestBg, isNot(equals(sfRestBg)));

    // "cur" on the surface row lifts the surface one state step: the strip
    // resolves the surface group through a resolver bound to the surface.
    final sfCurRect = frame.hits.rectOf('strip/sf/fill/cur');
    expect(sfCurRect, isNotNull, reason: "the surface group's cur chip paints under its own tag");
    final sfCurBg = buffer[(x: sfCurRect!.x + 1, y: sfCurRect.y)].bg;
    expect(sfCurBg, equals(Theme.dark.surface.color!.shiftLightness(Theme.step)));

    // A wash keeps the ground's own text: the "sel" wash chip sets only a
    // background, so its fg still reads back as the background row's own
    // default text.
    final washSelRect = frame.hits.rectOf('strip/bg/wash/sel');
    expect(washSelRect, isNotNull, reason: "the wash row's sel chip paints under its own tag");
    final washSelCell = buffer[(x: washSelRect!.x + 1, y: washSelRect.y)];
    expect(washSelCell.bg, equals(Theme.dark.selection.color));
    expect(washSelCell.fg, equals(Theme.dark.background.on));
  });

  test('the state strip also paints on the reference page', () {
    final model = viewer.Model();
    var frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final ctx = UpdateContext(hits: frame.hits, area: frame.area);

    // Three F4 presses land on page 1, following the same cycle the header
    // test walks: gallery, contrast, states, reference.
    viewer.update(model, const KeyMsg('f4'), ctx);
    viewer.update(model, const KeyMsg('f4'), ctx);
    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    expect(_screenText(frame.buffer), contains('Page 1/4: Reference'));
    expect(
      frame.hits.rectOf('strip/bg/fill/rest'),
      isNotNull,
      reason: 'the reference page carries the same state strip as the gallery',
    );
  });

  test('the state strip renders without throwing under ANSI-16 and NO_COLOR', () {
    for (final policy in [RenderPolicy.ansi16, RenderPolicy.noColor]) {
      final model = viewer.Model()..policy = policy;
      final frame = _testFrame(160, 50);
      expect(() => viewer.view(model, frame), returnsNormally, reason: 'policy: $policy');
      expect(
        frame.hits.rectOf('strip/bg/fill/rest'),
        isNotNull,
        reason: 'the rest chip still paints under policy: $policy',
      );
    }
  });

  test('the contrast page prints the ratio Color.contrastRatio returns for default text', () {
    final model = viewer.Model();
    var frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final ctx = UpdateContext(hits: frame.hits, area: frame.area);

    // The viewer starts on the gallery (page 2); one F4 press reaches the
    // contrast page (page 3), the same step the header-cycling test takes.
    viewer.update(model, const KeyMsg('f4'), ctx);
    frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final screen = _screenText(frame.buffer);

    expect(screen, contains('Contrast: ratio is the WCAG 2 contrast ratio'));
    final ratio = Theme.dark.background.on.contrastRatio(Theme.dark.background.color!).toStringAsFixed(2);
    expect(screen, contains('$ratio:1'), reason: 'default text over background measures $ratio:1');
  });

  test('the contrast page renders for every theme under every render tier', () {
    for (var i = 0; i < viewer.Model.themes.length; i++) {
      for (final policy in RenderPolicy.values) {
        final model = viewer.Model()
          ..themeIndex = i
          ..page = 3
          ..policy = policy;
        final frame = _testFrame(160, 50);
        final label = '${viewer.Model.themes[i].name} / $policy';
        expect(() => viewer.view(model, frame), returnsNormally, reason: label);
        expect(_screenText(frame.buffer), contains('Contrast: ratio is the WCAG 2 contrast ratio'), reason: label);
      }
    }
  });

  test("the contrast page shows every theme's muted, disabled, and border ratios", () {
    for (var i = 0; i < viewer.Model.themes.length; i++) {
      final theme = viewer.Model.themes[i];
      final model = viewer.Model()
        ..themeIndex = i
        ..page = 3;
      final frame = _testFrame(160, 50);
      viewer.view(model, frame);
      final screen = _screenText(frame.buffer);

      // Computed the way the page computes them, from the theme as it is, so
      // the assertion never hard-codes a number a theme could still change.
      // The three neutrals all read against the background.
      final ground = theme.background.color!;
      final mutedRatio = theme.muted.color!.contrastRatio(ground).toStringAsFixed(2);
      final disabledRatio = theme.disabled.color!.contrastRatio(ground).toStringAsFixed(2);
      final borderRatio = theme.border.color!.contrastRatio(ground).toStringAsFixed(2);

      expect(screen, contains('$mutedRatio:1'), reason: '${theme.name}: muted / background measures $mutedRatio:1');
      expect(
        screen,
        contains('$disabledRatio:1'),
        reason: '${theme.name}: disabled / background measures $disabledRatio:1',
      );
      expect(screen, contains('$borderRatio:1'), reason: '${theme.name}: background / border measures $borderRatio:1');
    }
  });

  test('the states page labels a row on the window half and on the surface half, under every tier', () {
    for (final policy in RenderPolicy.values) {
      final model = viewer.Model()
        ..page = 4
        ..policy = policy;
      final frame = _testFrame(160, 50);
      expect(() => viewer.view(model, frame), returnsNormally, reason: 'policy: $policy');
      final lines = _screenText(frame.buffer).split('\n');

      // The halves split the width, so a label left of the middle belongs to
      // the window and one right of it to the dialog panel.
      final split = frame.buffer.area.width ~/ 2;
      final focusedColumns = [
        for (final line in lines)
          for (final match in 'focused'.allMatches(line))
            if (!line.contains('Page')) match.start,
      ];
      expect(focusedColumns.any((x) => x < split), isTrue, reason: 'window half, $policy');
      expect(focusedColumns.any((x) => x >= split), isTrue, reason: 'dialog half, $policy');

      final screen = lines.join('\n');
      expect(screen, contains('Page 4/4: States'), reason: '$policy');
      expect(screen, contains('step ${Theme.step.toStringAsFixed(2)}'), reason: '$policy');
      expect(screen, contains('de-emphasis ${model.theme.deEmphasis.toStringAsFixed(2)}'), reason: '$policy');
    }
  });

  test('the states page grounds the right half on the surface and keeps the halves distinct', () {
    final model = viewer.Model()..page = 4;
    final frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final buffer = frame.buffer;

    expect(buffer[(x: 2, y: 8)].bg, equals(Theme.dark.background.color));
    expect(buffer[(x: 100, y: 8)].bg, equals(Theme.dark.surface.color));
    expect(model.states.window.prefix, isNot(equals(model.states.dialog.prefix)));
  });

  test('the states page shows a Button, a Checkbox, a RadioGroup and a TextInput per state on both halves', () {
    final model = viewer.Model()..page = 4;
    final frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final split = frame.buffer.area.width ~/ 2;

    for (final (half, onRight) in [(model.states.window, false), (model.states.dialog, true)]) {
      final ids = [
        for (final m in half.buttons.values) m.id,
        for (final m in half.checkboxes.values) m.id,
        for (final m in half.radioGroups.values) m.id,
        for (final m in half.textInputs.values) m.id,
        half.errorInput.id,
      ];
      expect(ids, hasLength(20));
      for (final id in ids) {
        final rect = frame.hits.rectOf(id);
        expect(rect, isNotNull, reason: id);
        expect(id, startsWith(half.prefix));
        expect(rect!.x >= split, onRight, reason: id);
      }
    }
    expect(_screenText(frame.buffer), isNot(contains('added by its batch')));
  });

  test('the states page paints the pressed checkbox row lifted, and the same row differently on the surface', () {
    final model = viewer.Model()..page = 4;
    final frame = _testFrame(160, 50);
    viewer.view(model, frame);
    final resolver = StyleResolver(model.theme);
    final onWindow = frame.hits.rectOf(model.states.window.checkboxes['pressed']!.id)!;
    final onSurface = frame.hits.rectOf(model.states.dialog.checkboxes['pressed']!.id)!;

    expect(
      frame.buffer[(x: onWindow.x, y: onWindow.y)].bg,
      resolver.resolve(null, {WidgetState.pressed}, cls: PaintClass.fill).bg,
    );
    final surface = resolver.on(resolver.tones.surface);
    expect(
      frame.buffer[(x: onSurface.x, y: onSurface.y)].bg,
      surface.resolve(null, {WidgetState.pressed}, cls: PaintClass.fill).bg,
    );
  });

  test('the d key on the states page de-emphasises the window half only, and d elsewhere does nothing', () {
    const ctx = UpdateContext(hits: HitMap.empty(), area: Rect.zero);
    final model = viewer.Model()..page = 2;
    viewer.update(model, const KeyMsg('d'), ctx);
    expect(model.states.dialogOpen, isFalse, reason: 'page 2 leaves the key to the widgets');

    model.page = 4;
    final plain = _testFrame(160, 50);
    viewer.view(model, plain);
    expect(_screenText(plain.buffer), isNot(contains('window de-emphasised: a dialog is open')));

    viewer.update(model, const KeyMsg('d'), ctx);
    expect(model.states.dialogOpen, isTrue);
    final open = _testFrame(160, 50);
    viewer.view(model, open);
    expect(_screenText(open.buffer), contains('window de-emphasised: a dialog is open'));

    final resolver = StyleResolver(model.theme);
    // Window border (top-left corner of the page body) goes quiet; the surface
    // half's border (its top-left corner) does not change.
    final rect = open.hits.rectOf(model.states.window.buttons['rest']!.id)!;
    final openFace = open.buffer[(x: rect.x, y: rect.y)].bg;
    final plainFace = plain.buffer[(x: rect.x, y: rect.y)].bg;
    expect(openFace, resolver.deEmphasised.fill(resolver.tones.primary).bg);
    expect(openFace, isNot(plainFace));

    final dlg = open.hits.rectOf(model.states.dialog.buttons['rest']!.id)!;
    expect(open.buffer[(x: dlg.x, y: dlg.y)], plain.buffer[(x: dlg.x, y: dlg.y)]);

    viewer.update(model, const KeyMsg('d'), ctx);
    expect(model.states.dialogOpen, isFalse);
  });

  test('an open dialog on the gallery page builds the host through the de-emphasised resolver', () {
    final model = viewer.Model();
    final plain = _testFrame(160, 50);
    viewer.view(model, plain);
    model.modal = ModalModel(id: 'demo-dialog');
    final open = _testFrame(160, 50);
    viewer.view(model, open);

    final resolver = StyleResolver(model.theme);
    // The header's border corner sits at the frame's top-left.
    expect(plain.buffer[(x: 0, y: 0)].fg, resolver.border(const {}).fg);
    expect(open.buffer[(x: 0, y: 0)].fg, resolver.deEmphasised.border(const {}).fg);
    expect(open.hits.rectOf('demo-dialog'), isNotNull);
  });

  test('the states page forces each list row into its state on both halves, and opens both popups', () {
    final model = viewer.Model()..page = 4;
    final frame = _testFrame(130, 60);
    viewer.view(model, frame);
    final window = StyleResolver(model.theme);
    final surface = window.on(window.tones.surface);

    for (final (half, r) in [(model.states.window, window), (model.states.dialog, surface)]) {
      final rect = frame.hits.rectOf(half.cursorList.id)!;
      // The last cell of a row is fill only, so it shows the row's own look.
      Cell row(int index) => frame.buffer[(x: rect.x + rect.width - 1, y: rect.y + index)];
      final ground = r.ground(r.groundTone);

      expect(row(0).bg == ground.bg || row(0).bg == Color.reset, isTrue, reason: '${half.prefix} rest');
      expect(
        row(1).bg,
        r.resolve(null, {WidgetState.cursor}, cls: PaintClass.fill).bg,
        reason: '${half.prefix} cursor',
      );
      expect(row(2).bg, r.fill(r.tones.selection).bg, reason: '${half.prefix} selected');
      expect(row(3).bg, r.fill(r.tones.selection).bg, reason: '${half.prefix} selected + error');
      expect(row(4).bg, r.resolve(null, {WidgetState.hover}, cls: PaintClass.fill).bg, reason: '${half.prefix} hover');
      expect(row(5).modifier.has(Modifier.dim), isTrue, reason: '${half.prefix} disabled');
      // The error cell keeps one ink on both grounds, over the selection fill.
      final errorCell = frame.buffer[(x: rect.x, y: rect.y + 3)];
      expect(errorCell.fg, equals(model.theme.error.color), reason: '${half.prefix} error ink');

      final focusedRect = frame.hits.rectOf(half.focusedList.id)!;
      final focusedCell = frame.buffer[(x: focusedRect.x + focusedRect.width - 1, y: focusedRect.y)];
      expect(
        focusedCell.bg,
        r.resolve(null, {WidgetState.cursor, WidgetState.focused}, cls: PaintClass.fill).bg,
        reason: '${half.prefix} focused cursor',
      );
      expect(focusedCell.modifier.has(Modifier.bold), isTrue);

      expect(half.combobox.isOpen, isTrue);
    }

    // Both popups paint: each half shows the first option once.
    final text = _screenText(frame.buffer);
    expect('Admin'.allMatches(text).length, 2);
  });
}
