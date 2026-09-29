import 'models.dart';

/// Number of person colours (same as `personPaletteSize` in lib/app/palette.dart;
/// kept here so lib/core stays free of Flutter imports).
const _paletteSize = 8;

/// The palette index [m] is shown with: their saved colour, or the one
/// [missingColorAssignments] would give them.
int effectiveColorIndex(Member m, List<Member> all) {
  final color = m.color;
  if (color != null) return color;
  final everyone = all.any((x) => x.uid == m.uid) ? all : [...all, m];
  return missingColorAssignments(everyone)[m.uid]!;
}

/// Colours for members that have none yet. Members are taken in join order
/// (unknown join times last, then by uid); each gets the lowest index 0–7 not
/// used by a coloured member or by an earlier assignment. Once all 8 are
/// used, the next index is (number of colours in use) % 8.
Map<String, int> missingColorAssignments(List<Member> all) {
  final used = <int>[
    for (final m in all)
      if (m.color != null) m.color! % _paletteSize,
  ];
  final missing = all.where((m) => m.color == null).toList()
    ..sort((a, b) {
      final ja = a.joinedAt;
      final jb = b.joinedAt;
      if (ja != null && jb != null) {
        final byTime = ja.compareTo(jb);
        if (byTime != 0) return byTime;
      } else if (ja != null) {
        return -1;
      } else if (jb != null) {
        return 1;
      }
      return a.uid.compareTo(b.uid);
    });

  final result = <String, int>{};
  for (final m in missing) {
    var index = -1;
    for (var i = 0; i < _paletteSize; i++) {
      if (!used.contains(i)) {
        index = i;
        break;
      }
    }
    if (index == -1) index = used.length % _paletteSize;
    used.add(index);
    result[m.uid] = index;
  }
  return result;
}
