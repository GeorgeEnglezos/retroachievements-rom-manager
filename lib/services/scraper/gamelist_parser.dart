import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../../models/scraped_game.dart';

/// EmulationStation `<tag>` -> our image type. Heuristic: ES `<thumbnail>` is
/// conventionally box art, `<image>` the in-game screenshot.
// Fixed mapping; no scraper layout seen so far needs it configurable.
const Map<String, String> _imageTags = {
  'thumbnail': 'boxart',
  'image': 'screenshot',
  'marquee': 'marquee',
  'titleshot': 'title',
  'fanart': 'fanart',
  'video': 'video',
};

/// Parses one gamelist.xml into [ScrapedGame]s. Relative `<path>`/`<image>`/etc.
/// resolve against the gamelist's own folder into absolute native paths; image
/// tags whose file is absent on disk are dropped. Throws on malformed XML.
List<ScrapedGame> parseGamelist(File xmlFile) {
  final base = xmlFile.parent.path;
  final doc = XmlDocument.parse(xmlFile.readAsStringSync());
  final games = <ScrapedGame>[];
  for (final g in doc.findAllElements('game')) {
    final rel = _text(g, 'path');
    if (rel == null) continue;
    final romPath = p.normalize(p.join(base, rel));

    final images = <String, String>{};
    for (final e in _imageTags.entries) {
      final v = _text(g, e.key);
      if (v == null) continue;
      final abs = p.normalize(p.join(base, v));
      if (File(abs).existsSync()) images[e.value] = abs;
    }

    games.add(ScrapedGame(
      romPath: romPath,
      title: _text(g, 'name') ?? p.basenameWithoutExtension(romPath),
      desc: _text(g, 'desc'),
      developer: _text(g, 'developer'),
      publisher: _text(g, 'publisher'),
      genre: _text(g, 'genre'),
      releaseDate: _normDate(_text(g, 'releasedate')),
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

// ES releasedate is %Y%m%dT%H%M%S. -> 'YYYY-MM-DD', or 'YYYY' when M/D are 00.
String? _normDate(String? raw) {
  if (raw == null || raw.length < 4) return null;
  final year = raw.substring(0, 4);
  if (int.tryParse(year) == null) return raw;
  if (raw.length >= 8) {
    final m = raw.substring(4, 6), d = raw.substring(6, 8);
    if (m != '00' && d != '00') return '$year-$m-$d';
  }
  return year;
}
