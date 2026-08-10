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

  /// The written (ketiv) form, when [text] is the form the Masoretes
  /// marked as the one to be read. Only ever one of [ketiv]/[qere] is
  /// set, and never for Greek — `w` and `strongs` always describe the
  /// same word, and this is the other form of it.
  final String? ketiv;

  /// The read (qere) form, when [text] is the written one. Used where
  /// the read form carries no Strong's number of its own (the לא/לו
  /// crux and 18 others), so showing it as the headword would print it
  /// under a number that belongs to a different word.
  final String? qere;

  const OriginalWord({
    required this.text,
    required this.strongs,
    this.translit,
    this.morph,
    this.ketiv,
    this.qere,
  });

  factory OriginalWord.fromJson(Map<String, dynamic> json) {
    return OriginalWord(
      text: (json['w'] ?? '') as String,
      strongs: (json['s'] ?? '') as String,
      translit: json['t'] as String?,
      morph: json['m'] as String?,
      ketiv: json['k'] as String?,
      qere: json['q'] as String?,
    );
  }
}
