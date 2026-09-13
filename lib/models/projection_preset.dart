/// One named 投影 setup — the whole control strip in a word.
///
/// The operator who drives the hall on a Sunday morning and the one who
/// drives the Wednesday study are frequently the same person with two
/// different answers: a bigger type for the morning congregation in a
/// bright room, one edition for the study group who all read the same
/// one. Both of them are three or four adjustments, and re-making them
/// weekly from the back of a hall while people are arriving is the part
/// of this feature that was missing.
///
/// A plain value object rather than a slice of `AppSettings`, because
/// the LIVE setup and a REMEMBERED one are different things: the live
/// one is what the wall is doing right now, a preset is a note about
/// what it should be doing. Keeping them the same type would make
/// "apply" and "save" the same operation, and they are opposites.
///
/// ## WHAT IT DOES NOT CARRY
///
/// Not the blank state, and not the cursor. Blanking is a moment, not a
/// setup (see `projection_page.dart`), and the passage on the wall
/// belongs to whatever the reader has open — a preset that also moved
/// the projection to Genesis 1 would be a slide deck, which this page
/// deliberately is not.
///
/// ## THE STORED CODES ARE NOT RESOLVED HERE
///
/// [secondVersion] and [groundName] are kept exactly as they were
/// written, unvalidated. A preset saved on a phone that ships the LEB
/// and recalled on a web build that strips it must not be silently
/// rewritten on disk — the reader may open the same profile on the
/// device that does have it. Both are clamped where they are READ (the
/// page runs [secondVersion] through the same resolver the second
/// edition's loader uses, and [groundName] through
/// `projectionGroundFromName`), which is the pattern
/// `_kInterlinearVersion` in `app_settings.dart` already sets.
library;

import 'package:flutter/foundation.dart';

@immutable
class ProjectionPreset {
  const ProjectionPreset({
    required this.name,
    required this.typeStep,
    required this.secondOn,
    required this.secondVersion,
    required this.groundName,
  });

  /// What the operator called it. Also its identity: saving under an
  /// existing name replaces that preset rather than making a second one,
  /// because "morning service" twice in a list is not two setups, it is
  /// one setup the operator has adjusted.
  final String name;

  /// An index into `kProjectionTypeSteps`. Stored as the STEP and not as
  /// a pixel size so a future change to the ladder moves an old preset
  /// with it instead of stranding it between two rungs.
  final int typeStep;

  final bool secondOn;

  /// The second edition's code as it stood when this was saved — see the
  /// library doc on why it is not resolved here.
  final String secondVersion;

  /// A `ProjectionGround.name`. A string rather than the enum so this
  /// model stays free of the widget layer, and so a ground that is
  /// renamed or withdrawn degrades to the default instead of failing to
  /// parse the whole preset.
  final String groundName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'typeStep': typeStep,
        'secondOn': secondOn,
        'secondVersion': secondVersion,
        'groundName': groundName,
      };

  /// One row of the stored list, or null when the row is not a preset.
  ///
  /// Null rather than a guessed preset for the two fields that have no
  /// sensible default — an unnamed preset cannot be shown in a list, and
  /// a missing type step would have to be invented. The other three are
  /// leniently defaulted, because each of them already has a documented
  /// fallback at the point of use and a partially-readable preset is
  /// worth more to an operator than none.
  static ProjectionPreset? fromJson(Map<String, dynamic> m) {
    final name = m['name'];
    final step = m['typeStep'];
    if (name is! String || name.isEmpty || step is! num) return null;
    return ProjectionPreset(
      name: name,
      typeStep: step.toInt(),
      secondOn: m['secondOn'] == true,
      secondVersion: m['secondVersion'] is String
          ? m['secondVersion'] as String
          : '',
      groundName:
          m['groundName'] is String ? m['groundName'] as String : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectionPreset &&
      other.name == name &&
      other.typeStep == typeStep &&
      other.secondOn == secondOn &&
      other.secondVersion == secondVersion &&
      other.groundName == groundName;

  @override
  int get hashCode =>
      Object.hash(name, typeStep, secondOn, secondVersion, groundName);

  @override
  String toString() => 'ProjectionPreset($name, step $typeStep, '
      'second ${secondOn ? secondVersion : "off"}, ground $groundName)';
}
