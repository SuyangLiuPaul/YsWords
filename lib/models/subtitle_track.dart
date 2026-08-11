/// One subtitle line and the window it belongs on screen.
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;
  const SubtitleCue(this.start, this.end, this.text);

  bool contains(Duration t) => t >= start && t < end;
}

/// A parsed WebVTT track.
///
/// Parsed in-app rather than handed to the platform player because the
/// player has to stay identical across web, iOS, Android and macOS —
/// `video_player` exposes no caption API on all four, and a subtitle
/// that appears on one platform and not another is worse than one that
/// is drawn by us everywhere.
class SubtitleTrack {
  final List<SubtitleCue> cues;
  const SubtitleTrack(this.cues);

  static const empty = SubtitleTrack(<SubtitleCue>[]);

  bool get isEmpty => cues.isEmpty;

  /// The cue covering [t], or null in a gap between lines.
  ///
  /// Binary search, not a scan: this runs on every position tick of a
  /// 17-minute video against ~180 cues, and a linear scan there is
  /// wasted work on every frame.
  SubtitleCue? cueAt(Duration t) {
    var lo = 0, hi = cues.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final c = cues[mid];
      if (t < c.start) {
        hi = mid - 1;
      } else if (t >= c.end) {
        lo = mid + 1;
      } else {
        return c;
      }
    }
    return null;
  }

  /// Parse WebVTT.
  ///
  /// Deliberately tolerant: a malformed line is skipped rather than
  /// throwing, because a subtitle file is an accessory — a parse error
  /// must never be able to take down the video it belongs to.
  factory SubtitleTrack.parse(String vtt) {
    final cues = <SubtitleCue>[];
    final lines = vtt.replaceAll('\r\n', '\n').split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.contains('-->')) continue;
      final parts = line.split('-->');
      if (parts.length != 2) continue;
      final start = _parseTime(parts[0].trim());
      final end = _parseTime(parts[1].trim().split(' ').first);
      if (start == null || end == null || end <= start) continue;
      final buf = <String>[];
      var j = i + 1;
      while (j < lines.length && lines[j].trim().isNotEmpty) {
        buf.add(lines[j].trim());
        j++;
      }
      if (buf.isNotEmpty) {
        cues.add(SubtitleCue(start, end, buf.join('\n')));
      }
      i = j;
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return SubtitleTrack(cues);
  }

  /// `HH:MM:SS.mmm` or `MM:SS.mmm`.
  static Duration? _parseTime(String s) {
    final m = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})$')
        .firstMatch(s);
    if (m == null) return null;
    final ms = m.group(4)!.padRight(3, '0');
    return Duration(
      hours: int.tryParse(m.group(1) ?? '0') ?? 0,
      minutes: int.parse(m.group(2)!),
      seconds: int.parse(m.group(3)!),
      milliseconds: int.parse(ms),
    );
  }
}
