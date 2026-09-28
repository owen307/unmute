int _seq = 0;

/// Short unique ids for cues and steps. Not a security token.
String newId(String prefix) {
  _seq = (_seq + 1) & 0x7fffffff;
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_seq';
}
