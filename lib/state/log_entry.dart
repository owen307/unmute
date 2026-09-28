class OscLogEntry {
  OscLogEntry({
    required this.at,
    required this.title,
    required this.detail,
    required this.dryRun,
    required this.ok,
  });

  final DateTime at;
  final String title;
  final String detail;
  final bool dryRun;
  final bool ok;

  factory OscLogEntry.note(String title, {String detail = ''}) {
    return OscLogEntry(
      at: DateTime.now(),
      title: title,
      detail: detail,
      dryRun: false,
      ok: true,
    );
  }

  factory OscLogEntry.error(String title, {String detail = ''}) {
    return OscLogEntry(
      at: DateTime.now(),
      title: title,
      detail: detail,
      dryRun: false,
      ok: false,
    );
  }
}

String formatClock(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
