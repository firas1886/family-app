import 'package:flutter/material.dart';

/// One person's colour in one theme: a strong [fill] with [onFill] text,
/// and a light [tint] with [onTint] text.
class PersonColor {
  const PersonColor({required this.fill, required this.onFill, required this.tint, required this.onTint});
  final Color fill;
  final Color onFill;
  final Color tint;
  final Color onTint;

  @override
  bool operator ==(Object other) =>
      other is PersonColor &&
      other.fill == fill &&
      other.onFill == onFill &&
      other.tint == tint &&
      other.onTint == onTint;

  @override
  int get hashCode => Object.hash(fill, onFill, tint, onTint);
}

const int personPaletteSize = 8;

/// Stops 50, 100, 200, 600, 800, 900 of one palette colour.
class _Ramp {
  const _Ramp(this.s50, this.s100, this.s200, this.s600, this.s800, this.s900);
  final Color s50;
  final Color s100;
  final Color s200;
  final Color s600;
  final Color s800;
  final Color s900;
}

const _ramps = <_Ramp>[
  // 0 teal
  _Ramp(Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF5DCAA5), Color(0xFF0F6E56), Color(0xFF085041), Color(0xFF04342C)),
  // 1 coral
  _Ramp(Color(0xFFFAECE7), Color(0xFFF5C4B3), Color(0xFFF0997B), Color(0xFF993C1D), Color(0xFF712B13), Color(0xFF4A1B0C)),
  // 2 amber
  _Ramp(Color(0xFFFAEEDA), Color(0xFFFAC775), Color(0xFFEF9F27), Color(0xFF854F0B), Color(0xFF633806), Color(0xFF412402)),
  // 3 purple
  _Ramp(Color(0xFFEEEDFE), Color(0xFFCECBF6), Color(0xFFAFA9EC), Color(0xFF534AB7), Color(0xFF3C3489), Color(0xFF26215C)),
  // 4 blue
  _Ramp(Color(0xFFE6F1FB), Color(0xFFB5D4F4), Color(0xFF85B7EB), Color(0xFF185FA5), Color(0xFF0C447C), Color(0xFF042C53)),
  // 5 pink
  _Ramp(Color(0xFFFBEAF0), Color(0xFFF4C0D1), Color(0xFFED93B1), Color(0xFF993556), Color(0xFF72243E), Color(0xFF4B1528)),
  // 6 green
  _Ramp(Color(0xFFEAF3DE), Color(0xFFC0DD97), Color(0xFF97C459), Color(0xFF3B6D11), Color(0xFF27500A), Color(0xFF173404)),
  // 7 gray
  _Ramp(Color(0xFFF1EFE8), Color(0xFFD3D1C7), Color(0xFFB4B2A9), Color(0xFF5F5E5A), Color(0xFF444441), Color(0xFF2C2C2A)),
];

/// The colour for palette [index] (taken modulo 8, so any int is safe) in a theme.
PersonColor personColor(int index, Brightness brightness) {
  final ramp = _ramps[index % personPaletteSize];
  return brightness == Brightness.light
      ? PersonColor(fill: ramp.s600, onFill: const Color(0xFFFFFFFF), tint: ramp.s50, onTint: ramp.s800)
      : PersonColor(fill: ramp.s200, onFill: ramp.s900, tint: ramp.s800, onTint: ramp.s100);
}
