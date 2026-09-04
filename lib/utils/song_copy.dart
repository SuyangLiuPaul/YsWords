import 'package:yswords/models/song.dart';
import 'package:yswords/utils/entry_copy.dart';

/// The `source · code · credit · duration` line printed under a song's
/// title.
///
/// One builder, used by the screen AND by every copy action, because
/// the song detail sheet and the now-playing screen both draw it and
/// both copy it. Two builders for one line drift, and the drift stays
/// invisible until somebody compares a paste against the screen.
///
/// Absent parts are simply left out rather than filled in — a song with
/// no catalogue number and no credit line reads as its source alone,
/// not as a row of empty separators.
String songMetaLine(Song song, String locale) => [
      localizedSongSource(song.source, locale),
      if (song.code != null) song.code!,
      if (song.creditLine != null) song.creditLine!,
      if (song.durationLabel != null) song.durationLabel!,
    ].join(' · ');

/// A song for the clipboard: title, [songMetaLine], and its source page.
///
/// **Deliberately no lyrics.** Neither the detail sheet nor the
/// now-playing screen displays them, so there is nothing on either
/// screen to take. More to the point, this catalogue is already
/// deliberate about whose words it carries: `fetch_setapak` in
/// yswords-data skips lyrics because those two posts are covers this
/// catalogue cannot license, while `fetch_ydh` carries them because
/// that ministry publishes its own. Displaying words under that
/// arrangement and handing out a one-tap extract of them are not the
/// same act, so widening this is the owner's decision to make and not a
/// gap to be tidied up.
String songCopyText(Song song, String locale) => formatEntryForCopy(
      heading: song.title,
      body: songMetaLine(song, locale),
      url: song.url,
    );
