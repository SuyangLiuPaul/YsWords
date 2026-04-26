/// One word of the original-language Bible text (Hebrew OT or Greek NT).
///
/// `text` is the surface form as it appears in the source; `strongs` is
/// the Strong's number ("G####"/"H####") that links to a [StrongsEntry].
/// `translit` is optional — included when the source provides it inline
/// so we don't have to look it up separately.
class OriginalWord {
  final String text;
  final String strongs;
  final String? translit;
  final String? morph;

  const OriginalWord({
    required this.text,
    required this.strongs,
    this.translit,
    this.morph,
  });

  factory OriginalWord.fromJson(Map<String, dynamic> json) {
    return OriginalWord(
      text: (json['w'] ?? '') as String,
      strongs: (json['s'] ?? '') as String,
      translit: json['t'] as String?,
      morph: json['m'] as String?,
    );
  }
}
