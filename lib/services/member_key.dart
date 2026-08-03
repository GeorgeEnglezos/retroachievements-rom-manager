/// Computes the playlist membership key for a game/file. Matched games are keyed
/// by RA game id so all copies/regions collapse to one entry and survive
/// renames; unmatched files fall back to their path.
String memberKeyFor({required int? gameId, required String filePath}) =>
    gameId != null ? 'ra:$gameId' : 'path:$filePath';
