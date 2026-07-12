import 'dart:io';

import 'package:kiko/kiko.dart';

// ═══════════════════════════════════════════════════════════
// Paste + focus echo.
//
// The two event types no other example touches. Both need a terminal mode
// turned on, so the app opts in with `bracketedPaste` and `focusEvents`:
//
//   • bracketed paste → a whole paste arrives as ONE `PasteMsg`, not a burst of
//     key events. Paste multi-line text and watch a single event land.
//   • focus reporting → switching away from and back to the terminal window
//     delivers a `FocusMsg`; the badge flips BLURRED / FOCUSED.
// ═══════════════════════════════════════════════════════════

class Model {
  bool focused = true;
  String? lastPaste;
  int pasteCount = 0;
  final List<String> log = [];

  void note(String line) {
    log.insert(0, line);
    if (log.length > 8) log.removeLast();
  }
}

(Model, Cmd?) update(Model model, Msg msg, UpdateContext _) {
  switch (msg) {
    case KeyMsg(key: 'q'):
      return (model, const Quit());

    case final PasteMsg m:
      model
        ..lastPaste = m.text
        ..pasteCount += 1
        ..note('paste  · ${m.text.length} chars, ${_lineCount(m.text)} line(s)');
      return (model, null);

    case final FocusMsg m:
      model
        ..focused = m.hasFocus
        ..note(m.hasFocus ? 'focus  · gained' : 'focus  · lost');
      return (model, null);

    default:
      return (model, null);
  }
}

int _lineCount(String text) => text.split('\n').length;

void view(Model model, Frame frame) {
  final badge = model.focused
      ? const Text(
          ' FOCUSED ',
          style: Style(fg: Color.black, bg: Color.green, addModifier: Modifier.bold),
        )
      : const Text(
          ' BLURRED ',
          style: Style(fg: Color.black, bg: Color.yellow, addModifier: Modifier.bold),
        );

  final ui = Container(
    border: BorderType.plain,
    borderStyle: Style(fg: model.focused ? Color.green : Color.darkGray),
    topTitles: [Line('Paste + focus echo')],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Line('window focus: '),
            Line.fromTexts([badge]),
          ],
        ),
        const SizedBox(height: 1),
        Line(
          'Paste some text (try multiple lines) · switch windows to blur · q quits',
          style: const Style(fg: Color.darkGray),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Row(
            crossAxis: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _pastePanel(model)),
              Expanded(child: _logPanel(model)),
            ],
          ),
        ),
      ],
    ),
  );

  frame.render(ui);
}

View _pastePanel(Model model) => Container(
  border: BorderType.rounded,
  topTitles: [Line('last paste (#${model.pasteCount})')],
  child: model.lastPaste == null
      ? Center(
          child: Line('— nothing pasted yet —', style: const Style(fg: Color.darkGray)),
        )
      : Column(
          crossAxis: CrossAxisAlignment.stretch,
          children: [
            for (final line in _preview(model.lastPaste!)) Line(line),
          ],
        ),
);

View _logPanel(Model model) => Container(
  border: BorderType.rounded,
  topTitles: [Line('event log')],
  child: Column(
    crossAxis: CrossAxisAlignment.stretch,
    children: [
      if (model.log.isEmpty)
        Center(
          child: Line('— waiting for events —', style: const Style(fg: Color.darkGray)),
        )
      else
        for (final line in model.log) Line(line, style: const Style(fg: Color.cyan)),
    ],
  ),
);

/// The first few lines of a paste, so a big paste does not blow past the panel.
List<String> _preview(String text) {
  final lines = text.split('\n');
  if (lines.length <= 6) return lines;
  return [...lines.take(6), '… +${lines.length - 6} more line(s)'];
}

Future<void> main() async {
  exit(
    await Application(
      title: 'Paste + focus echo',
      bracketedPaste: true,
      focusEvents: true,
    ).run(
      init: Model(),
      update: update,
      view: view,
    ),
  );
}
