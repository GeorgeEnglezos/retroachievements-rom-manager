/// One game's imported (Skraper / gamelist.xml) metadata, matched to a local
/// ROM by absolute file path. Separate from RA's [GameMetadata]/[GameInfo]:
/// this only fills RA's gaps and supplies extra local images (reference-in-place:
/// [images] values are absolute paths on disk, rendered with Image.file).
class ScrapedGame {
  final String romPath; // absolute path of the matched ROM; the store key
  final String title;
  final String? desc;
  final String? developer;
  final String? publisher;
  final String? genre;
  final String? releaseDate; // display string: 'YYYY' or 'YYYY-MM-DD'
  final String? players;
  final String? rating;

  /// image type -> absolute local file path. Keys: boxart, screenshot,
  /// marquee, title, fanart, video. Only present-and-existing files included.
  final Map<String, String> images;

  /// Best image for a list/grid thumbnail: the physical-media shot first
  /// (Skraper's `support` reads most cover-like), then box art, then whatever
  /// other image exists. Video is not an image.
  String? get thumbPath {
    final other = images.entries
        .where((e) => e.key != 'video')
        .map((e) => e.value)
        .toList();
    return images['support'] ??
        images['boxart'] ??
        (other.isEmpty ? null : other.first);
  }

  const ScrapedGame({
    required this.romPath,
    required this.title,
    this.desc,
    this.developer,
    this.publisher,
    this.genre,
    this.releaseDate,
    this.players,
    this.rating,
    this.images = const {},
  });

  factory ScrapedGame.fromJson(Map<String, dynamic> j) => ScrapedGame(
        romPath: j['romPath'] as String,
        title: j['title'] as String? ?? '',
        desc: j['desc'] as String?,
        developer: j['developer'] as String?,
        publisher: j['publisher'] as String?,
        genre: j['genre'] as String?,
        releaseDate: j['releaseDate'] as String?,
        players: j['players'] as String?,
        rating: j['rating'] as String?,
        images: (j['images'] as Map?)?.map(
                (k, v) => MapEntry(k as String, v as String)) ??
            const {},
      );

  Map<String, dynamic> toJson() => {
        'romPath': romPath,
        'title': title,
        if (desc != null) 'desc': desc,
        if (developer != null) 'developer': developer,
        if (publisher != null) 'publisher': publisher,
        if (genre != null) 'genre': genre,
        if (releaseDate != null) 'releaseDate': releaseDate,
        if (players != null) 'players': players,
        if (rating != null) 'rating': rating,
        if (images.isNotEmpty) 'images': images,
      };
}
