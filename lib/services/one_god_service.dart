import 'package:yswords/models/one_god_episode.dart';

/// 獨一真神 — the church's video teaching series.
///
/// Bundled rather than fetched. The whole dataset is the episode list
/// plus the transcript (28 KB), which is small enough that a network
/// round-trip would buy nothing; the 238 MB that actually matters is
/// the video, and that streams from the media host on demand.
class OneGodBundle {
  final List<OneGodEpisode> episodes;

  /// Host the video paths hang off. Kept out of the episode records so
  /// re-hosting is one value, not a rewrite of every entry — the same
  /// shape as the sermon audio service, which has been sitting dormant
  /// waiting for exactly this decision.
  final String videoBase;

  const OneGodBundle({required this.episodes, required this.videoBase});

  /// Absolute URL for a track.
  String urlFor(OneGodTrack t) => '$videoBase${t.path}';
}

class OneGodService {
  /// Overridable at build time so a different host — the church's own
  /// server, object storage — needs no code change.
  ///
  /// The default is a Netlify site the videos are deployed to directly
  /// from a folder. They are deliberately NOT in git: episode 01 alone
  /// is 238 MB across three languages, and a repo cannot un-swallow
  /// that once committed.
  static const String videoBase = String.fromEnvironment(
    'ONEGOD_VIDEO_BASE',
    defaultValue: 'https://yswords-media.netlify.app',
  );

  static const String assetPath = 'assets/onegod.json';
}
