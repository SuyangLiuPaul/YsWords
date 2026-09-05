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
/// **Still deliberately no lyrics** — but no longer because lyrics are
/// off limits. This is the *details* action, offered from three places
/// (the detail sheet header, the now-playing screen and the score
/// page), and two of those three do not draw the words at all. Lyrics
/// have their own button on the one screen that shows them, and its
/// own shape in [songLyricsCopyText]. Keeping them apart is what stops
/// someone who wanted a citation from getting forty lines of verse.
String songCopyText(Song song, String locale) => formatEntryForCopy(
      heading: song.title,
      body: songMetaLine(song, locale),
      url: song.url,
    );

/// A song's WORDS for the clipboard: title, the lyric body, then the
/// same `[songMetaLine]` + source page that [songCopyText] ends with.
///
/// Approved by the owner on 2026-09-05. Until then the catalogue
/// displayed lyrics but would not extract them, on the reasoning that
/// showing words and handing out a one-tap copy of them are not the
/// same act. That call has now been made; this is the widening, and it
/// is deliberately the *only* one — nothing else about who may take
/// what changed.
///
/// **What gates it is the data, not a flag.** There is no licence or
/// "do not reproduce" field on [Song]; the catalogue expresses the same
/// thing by simply not carrying words it cannot license. `fetch_ydh`
/// and the fydt sync ship `lyrics`; `fetch_setapak` omits them, because
/// those two rows are covers of songs the congregation does not own.
/// So `lyrics == null` already IS the restriction, and returning `''`
/// here — the [formatEntryForCopy] convention for "there is nothing to
/// offer, do not draw a button" — is how it is honoured. A song with no
/// words can never put its title on the clipboard under a Lyrics
/// heading.
///
/// The credit appears **once**. The title heads the paste and the
/// source line closes it, so a lyric pasted into a notes app says whose
/// it is and where it came from, and a reader who taps both buttons on
/// the sheet gets two coherent blocks rather than the same citation
/// twice inside one of them.
///
/// The body is passed through untouched apart from trimming the ends.
/// These are transcribed words with their own stanza breaks and their
/// own punctuation; re-wrapping or re-punctuating them here would be
/// editing somebody else's text on the way to the clipboard.
String songLyricsCopyText(Song song, String locale) {
  final body = song.lyrics?.trim() ?? '';
  if (body.isEmpty) return '';
  return formatEntriesForCopy([
    song.title,
    body,
    formatEntryForCopy(body: songMetaLine(song, locale), url: song.url),
  ]);
}
