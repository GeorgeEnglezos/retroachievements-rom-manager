import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../../models/scraped_game.dart';

/// Skraper's "DAT + media folder" recipe: a Logiqx/clrmamepro `.dat` of text
/// metadata plus a sibling `media/<type>/<rom basename>.png` tree, matched to
/// ROMs by filename. The counterpart to [parseGamelist] for this recipe.

/// media subfolder name -> our image type. Unknown folders keep their own name.
// Covers the Skraper folder names seen in the wild; add more as they turn up.
const Map<String, String> _mediaFolderTypes = {
  'images': 'boxart',
  'box': 'boxart',
  'box2dfront': 'boxart',
  'boxart': 'boxart',
  'covers': 'boxart',
  'support': 'support',
  'screenshot': 'screenshot',
  'screenshots': 'screenshot',
  'ss': 'screenshot',
  'snap': 'screenshot',
  'wheel': 'marquee',
  'wheels': 'marquee',
  'marquee': 'marquee',
  'logo': 'marquee',
  'titles': 'title',
  'titleshot': 'title',
  'fanart': 'fanart',
  'video': 'video',
  'videos': 'video',
};

const _imageExts = ['png', 'jpg', 'jpeg'];

/// Parses a Logiqx DAT into [ScrapedGame]s. Text comes from each `<game>`; the
/// ROM path resolves against the DAT's own folder (ROMs sit beside it, so the
/// resolved path matches a scanned ROM directly); images are discovered by
/// convention in a sibling `media/<type>/` folder named after the ROM basename.
/// Returns `[]` if the file isn't a Logiqx datafile (so a stray `.dat` is safe).
List<ScrapedGame> parseDat(File datFile) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(datFile.readAsStringSync());
  } catch (_) {
    return const [];
  }
  final root = doc.rootElement;
  if (root.name.local != 'datafile') return const [];

  final base = datFile.parent.path;
  final mediaDir = Directory(p.join(base, 'media'));
  final mediaSubs = mediaDir.existsSync()
      ? mediaDir.listSync(followLinks: false).whereType<Directory>().toList()
      : const <Directory>[];

  final games = <ScrapedGame>[];
  for (final g in root.findElements('game')) {
    final romName = g.getElement('rom')?.getAttribute('name');
    if (romName == null || romName.isEmpty) continue;
    final romPath = p.normalize(p.join(base, romName));
    final stem = p.basenameWithoutExtension(romName);

    final images = <String, String>{};
    for (final sub in mediaSubs) {
      final folder = p.basename(sub.path).toLowerCase();
      final type = _mediaFolderTypes[folder] ?? folder;
      for (final ext in _imageExts) {
        final f = File(p.join(sub.path, '$stem.$ext'));
        if (f.existsSync()) {
          images[type] = f.path;
          break;
        }
      }
    }

    games.add(ScrapedGame(
      romPath: romPath,
      title: g.getAttribute('name') ?? stem,
      desc: _text(g, 'description'),
      developer: _text(g, 'developer'),
      publisher: _text(g, 'manufacturer') ?? _text(g, 'publisher'),
      genre: _text(g, 'genre'),
      releaseDate: _text(g, 'year'),
      players: _text(g, 'players'),
      rating: _text(g, 'rating'),
      images: images,
    ));
  }
  return games;
}

String? _text(XmlElement g, String tag) {
  final t = g.getElement(tag)?.innerText.trim();
  return (t == null || t.isEmpty) ? null : t;
}
