import 'package:flutter/painting.dart' show Color;

import 'rom_row.dart';

/// One section in a grouped listing: a header label and its rows. Used by
/// folder's grouped-duplicates view and playlist's by-system view. [color] is
/// an optional accent stripe (duplicate groups).
class RomGroup {
  final String label;
  final List<RomRow> rows;
  final Color? color;
  const RomGroup({required this.label, required this.rows, this.color});
}
