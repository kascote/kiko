import 'package:characters/characters.dart';
import 'package:termunicode/termunicode.dart';

/// Sanitize the given [value] by removing non-printable characters and
/// replacing new lines and tabs.
Characters sanitizer(Characters value, {String replaceNewLine = '\n', String replaceTab = '  '}) {
  final buffer = StringBuffer();

  for (final char in value) {
    final out = switch (char) {
      '\n' || '\r' => replaceNewLine,
      '\t' => replaceTab,
      _ when isNonPrintableChar(char) || isPrivateChar(char) => null,
      _ => char,
    };
    if (out != null) buffer.write(out);
  }

  return buffer.toString().characters;
}
