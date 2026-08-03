import 'package:path/path.dart' as p;

/// Below this score a name match is flagged in the UI so the user can correct it.
const double kLowConfidenceThreshold = 0.6;

/// Reduces a ROM filename to a bare game title for name-based metadata matching.
/// Drops the extension, strips `(...)`/`[...]` tags (region, revision, disc),
/// and collapses `_`/`.`/whitespace separators.
String cleanRomName(String fileName) {
  var name = p.basenameWithoutExtension(fileName);
  name = name.replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), ' '); // (USA) [!] (Disc 1)
  name = name.replaceAll(RegExp(r'[._]'), ' '); // separators
  return name.replaceAll(RegExp(r'\s+'), ' ').trim();
}
