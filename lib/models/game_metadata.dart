/// Provider-neutral game metadata for RA-unsupported ("display-only") systems.
///
/// Deliberately a subset of [GameInfo]: only the fields every third-party
/// source can supply. RA keeps its richer `GameInfo` for supported systems;
/// this is the metadata-only path (no achievements, no progress).
class GameMetadata {
  final String providerId; // which provider produced this: 'ra', 'screenscraper'
  final String title;
  final String? publisher;
  final String? developer;
  final String? genre;
  final String? released; // provider-normalised display string (ISO or year)
  final String? imageUrl; // absolute url (third-party CDN); RA adapter may put an RA path here; the image widget branches on scheme
  final double matchConfidence; // 0..1 from fuzzy name match; 1.0 = exact/given
  final String? sourceRef; // provider's native id, for debugging/refresh

  const GameMetadata({
    required this.providerId,
    required this.title,
    this.publisher,
    this.developer,
    this.genre,
    this.released,
    this.imageUrl,
    this.matchConfidence = 1.0,
    this.sourceRef,
  });

  factory GameMetadata.fromJson(Map<String, dynamic> j) => GameMetadata(
        providerId: j['providerId'] as String? ?? '',
        title: j['title'] as String? ?? '',
        publisher: j['publisher'] as String?,
        developer: j['developer'] as String?,
        genre: j['genre'] as String?,
        released: j['released'] as String?,
        imageUrl: j['imageUrl'] as String?,
        matchConfidence: (j['matchConfidence'] as num?)?.toDouble() ?? 1.0,
        sourceRef: j['sourceRef'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'providerId': providerId,
        'title': title,
        'publisher': publisher,
        'developer': developer,
        'genre': genre,
        'released': released,
        'imageUrl': imageUrl,
        'matchConfidence': matchConfidence,
        'sourceRef': sourceRef,
      };
}
