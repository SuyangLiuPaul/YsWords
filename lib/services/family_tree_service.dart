import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/models/biblical_person.dart';

/// Loads the curated `assets/family_tree.json` dataset and provides
/// id-based lookups + a few traversal helpers used by the
/// FamilyTreePage and PersonDetailSheet.
///
/// Data shape: `{ "_meta": …, "people": [BiblicalPerson, …] }`. The
/// service caches the parsed list for the process lifetime; a single
/// asset read on first access.
class FamilyTreeService {
  FamilyTreeService._();
  static final FamilyTreeService instance = FamilyTreeService._();

  List<BiblicalPerson>? _list;
  Map<String, BiblicalPerson>? _byId;

  Future<List<BiblicalPerson>> loadAll() async {
    if (_list != null) return _list!;
    final raw = await rootBundle.loadString('assets/family_tree.json');
    final j = json.decode(raw) as Map<String, dynamic>;
    final entries = (j['people'] as List?) ?? const [];
    final list = entries
        .whereType<Map<String, dynamic>>()
        .map(BiblicalPerson.fromJson)
        .toList();
    _list = list;
    _byId = {for (final p in list) p.id: p};
    return list;
  }

  /// Synchronous lookup — caller must have awaited [loadAll] first.
  BiblicalPerson? byId(String id) => _byId?[id];

  /// Synchronous full-list accessor for callers that need every
  /// person but don't want to await. Returns `[]` when [loadAll]
  /// hasn't completed yet, so the result is always safe to iterate.
  List<BiblicalPerson> allOrEmpty() => _list ?? const [];

  Future<BiblicalPerson?> lookup(String id) async {
    await loadAll();
    return _byId?[id];
  }

  /// Persons with no `fatherId` AND no `motherId` AND no incoming
  /// reference as anyone's child — i.e. the trees' canonical roots
  /// for the browser to start from. In our MVP this collapses to
  /// just Adam + Eve (everyone else in the dataset descends from
  /// them through the named chain).
  Future<List<BiblicalPerson>> roots() async {
    final all = await loadAll();
    final referencedAsChild = <String>{};
    for (final p in all) {
      for (final c in p.childIds) {
        referencedAsChild.add(c);
      }
    }
    return all
        .where((p) =>
            p.fatherId == null &&
            p.motherId == null &&
            !referencedAsChild.contains(p.id))
        .toList();
  }

  /// Resolve child ids on a person to actual person objects, in
  /// declared order, dropping ids that aren't in the dataset.
  Future<List<BiblicalPerson>> children(BiblicalPerson p) async {
    await loadAll();
    return [
      for (final id in p.childIds)
        if (_byId?[id] != null) _byId![id]!,
    ];
  }

  /// Same shape as [children] but for spouses.
  Future<List<BiblicalPerson>> spouses(BiblicalPerson p) async {
    await loadAll();
    return [
      for (final id in p.spouseIds)
        if (_byId?[id] != null) _byId![id]!,
    ];
  }

  /// Walk up the father chain until we run out (root or missing id).
  /// Returns ancestors in *child-first* order: [parent, grandparent, …].
  /// Used by the detail sheet to render a quick "ancestry" trail.
  Future<List<BiblicalPerson>> patrilineage(BiblicalPerson p) async {
    await loadAll();
    final out = <BiblicalPerson>[];
    var cur = p;
    final seen = <String>{cur.id};
    while (cur.fatherId != null) {
      final f = _byId?[cur.fatherId];
      if (f == null || seen.contains(f.id)) break;
      out.add(f);
      seen.add(f.id);
      cur = f;
    }
    return out;
  }
}
