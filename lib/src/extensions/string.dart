/// String extensions
extension StringUtil on String {
  /// breaks a string into lines. If there is only a \r will not break at it.
  /// only breaks at \n or \n\r
  List<String> lines() => split(RegExp(r'\n\r?|\n\r'));
}
