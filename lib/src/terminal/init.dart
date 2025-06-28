// ignore_for_file: public_member_api_docs

import '../backend/termlib_backend.dart';
import 'terminal.dart';

Terminal? _term;

Future<Terminal> init() async {
  if (_term != null) _term!;
  _term = await Terminal.create(TermlibBackend());
  _term!.enableAlternateScreen();
  _term!.enableRawMode();

  return _term!;
}

Future<void> dispose() async {
  if (_term == null) return;
  _term!.disableRawMode();
  _term!.disableAlternateScreen();
  await _term!.flushThenExit(0);
}
