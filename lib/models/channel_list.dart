final _channelToken = RegExp(r'^(\d+)(?:\s*-\s*(\d+))?$');

/// Parses `1-4, 8` into channel numbers in written order.
///
/// Ranges run from the lower number to the higher one. Duplicates are dropped.
/// Throws [FormatException] when a token is not a channel or is outside
/// [min]–[max]. An empty string is an empty list.
List<int> parseChannelList(String input, {int min = 1, int max = 32}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const [];

  final result = <int>[];
  final seen = <int>{};
  for (final raw in trimmed.split(',')) {
    final part = raw.trim();
    if (part.isEmpty) continue;
    final match = _channelToken.firstMatch(part);
    if (match == null) {
      throw FormatException('Can\'t read "$part". Use numbers like 1-4, 8.');
    }
    var start = int.parse(match.group(1)!);
    var end = int.parse(match.group(2) ?? match.group(1)!);
    if (start > end) {
      final swap = start;
      start = end;
      end = swap;
    }
    for (var n = start; n <= end; n++) {
      if (n < min || n > max) {
        throw FormatException('Channel $n is outside $min–$max.');
      }
      if (seen.add(n)) result.add(n);
    }
  }
  return result;
}

/// Collapses runs that are consecutive in [channels] (`1, 2, 3, 8` → `1-3, 8`).
String formatChannelList(List<int> channels) {
  if (channels.isEmpty) return '';
  final parts = <String>[];
  var start = channels.first;
  var prev = start;
  for (var i = 1; i <= channels.length; i++) {
    final done = i == channels.length;
    final n = done ? null : channels[i];
    if (!done && n == prev + 1) {
      prev = n!;
      continue;
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    if (!done) {
      start = n!;
      prev = n;
    }
  }
  return parts.join(', ');
}
