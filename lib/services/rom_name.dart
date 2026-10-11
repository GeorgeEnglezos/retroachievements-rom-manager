import 'package:path/path.dart' as p;

/// [path]'s extension, lowercased and without the dot (`'iso'`), or `''`.
String bareExtension(String path) =>
    p.extension(path).replaceFirst('.', '').toLowerCase();

/// Reduces a ROM filename to a bare game title.
/// Drops the extension, strips `(...)`/`[...]` tags (region, revision, disc),
/// and collapses `_`/`.`/whitespace separators.
String cleanRomName(String fileName) {
  var name = p.basenameWithoutExtension(fileName);
  name = name.replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), ' '); // (USA) [!] (Disc 1)
  name = name.replaceAll(RegExp(r'[._]'), ' '); // separators
  return name.replaceAll(RegExp(r'\s+'), ' ').trim();
}
