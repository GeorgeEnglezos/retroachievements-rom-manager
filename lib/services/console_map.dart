import 'package:path/path.dart' as p;

/// Maps a subfolder name to an RA console id. The id must be right *before*
/// hashing: rcheevos uses it to pick the disc/header algorithm.
class ConsoleMap {
  ConsoleMap._();

  /// Console id -> name; limited to systems rcheevos can hash from files.
  static const Map<int, String> consoleNames = {
    1: 'Sega Mega Drive / Genesis',
    2: 'Nintendo 64',
    3: 'Super Nintendo',
    4: 'Game Boy',
    5: 'Game Boy Advance',
    6: 'Game Boy Color',
    7: 'NES / Famicom',
    8: 'PC Engine / TurboGrafx-16',
    9: 'Sega CD / Mega CD',
    10: 'Sega 32X',
    11: 'Sega Master System',
    12: 'PlayStation',
    13: 'Atari Lynx',
    14: 'SNK Neo Geo Pocket',
    15: 'Sega Game Gear',
    16: 'Nintendo GameCube',
    17: 'Atari Jaguar',
    18: 'Nintendo DS',
    78: 'Nintendo DSi',
    21: 'PlayStation 2',
    24: 'Nintendo Pokémon Mini',
    25: 'Atari 2600',
    27: 'Arcade',
    28: 'Nintendo Virtual Boy',
    39: 'Sega Saturn',
    40: 'Sega Dreamcast',
    41: 'PlayStation Portable',
    43: 'Panasonic 3DO',
    19: 'Nintendo Wii',
    51: 'Atari 7800',
    53: 'Bandai WonderSwan',
    76: 'PC Engine CD / TurboGrafx-CD',
    // Systems whose logos already shipped; rcheevos can hash all of these
    // (verified against rc_hash) so they match RA like any other.
    33: 'Sega SG-1000',
    44: 'ColecoVision',
    45: 'Mattel Intellivision',
    46: 'Vectrex',
    49: 'NEC PC-FX',
    56: 'SNK Neo Geo CD',
    57: 'Fairchild Channel F',
    62: 'Nintendo 3DS',
    77: 'Atari Jaguar CD',
    81: 'Famicom Disk System',
  };

  /// Display-only systems RetroAchievements can't hash/validate. Given stable
  /// negative synthetic ids so they persist through [SystemData.consoleId]
  /// without ever entering the hash/fetch path (see [isRaSupported]).
  static const Map<int, String> displayNames = {
    -1: 'Nintendo Switch',
    -2: 'Nintendo Wii U',
    -3: 'PlayStation 3',
    -4: 'PlayStation 4',
    -5: 'PlayStation Vita',
    -6: 'Xbox',
    -7: 'Xbox 360',
  };

  /// Console name for any id (hashable or display-only), or null if unknown.
  static String? nameFor(int? id) =>
      id == null ? null : (consoleNames[id] ?? displayNames[id]);

  /// True only when RA can hash and match this console. Drives whether a folder
  /// is hashed/fetched and whether the UI shows a "not supported" badge.
  static bool isRaSupported(int? id) => id != null && consoleNames.containsKey(id);

  /// RA console id -> manufacturer name. Used for grouping in UI.
  static const Map<int, String> _manufacturer = {
    // Nintendo
    2: 'Nintendo', 3: 'Nintendo', 4: 'Nintendo', 5: 'Nintendo',
    6: 'Nintendo', 7: 'Nintendo', 16: 'Nintendo', 18: 'Nintendo',
    24: 'Nintendo', 28: 'Nintendo', 19: 'Nintendo', 78: 'Nintendo',
    62: 'Nintendo', 81: 'Nintendo', -1: 'Nintendo', -2: 'Nintendo',
    // Sega
    1: 'Sega', 9: 'Sega', 10: 'Sega', 11: 'Sega',
    15: 'Sega', 39: 'Sega', 40: 'Sega', 33: 'Sega',
    // Sony
    12: 'Sony', 21: 'Sony', 41: 'Sony', -3: 'Sony', -4: 'Sony', -5: 'Sony',
    // Microsoft
    -6: 'Microsoft', -7: 'Microsoft',
    // Atari
    13: 'Atari', 17: 'Atari', 25: 'Atari', 51: 'Atari', 77: 'Atari',
    // NEC / Hudson
    8: 'NEC / Hudson', 76: 'NEC / Hudson', 49: 'NEC / Hudson',
    // SNK
    14: 'SNK', 56: 'SNK',
    // Panasonic
    43: 'Panasonic',
    // Bandai
    53: 'Bandai',
    // Arcade
    27: 'Arcade',
  };

  /// Manufacturers in sort order (unknown/Other sorts last).
  static const List<String> _manufacturerOrder = [
    'Nintendo', 'Sega', 'Sony', 'Microsoft', 'Atari',
    'NEC / Hudson', 'SNK', 'Panasonic', 'Bandai', 'Arcade',
  ];

  /// Ordered alias table, most specific first ("gba" before "gb"); matched
  /// as lowercase substrings.
  static const List<({List<String> aliases, int id})> _aliases = [
    // Must precede PlayStation: 'cps1'/'cps2' contain 'ps1'/'ps2'.
    (aliases: ['cps1', 'cps2', 'cps3'], id: 27),
    // Newly wired systems + display-only non-RA systems (negative ids). Placed
    // high so multi-word names win over the shorter base aliases below
    // ('wii u' before 'wii', 'jaguar cd' before 'jaguar', 'xbox 360' before
    // 'xbox'). Kept below the CPS guard so 'cps3' stays Arcade, not PS3.
    (aliases: ['nintendo switch', 'switch'], id: -1),
    (aliases: ['nintendo wii u', 'wii u', 'wiiu'], id: -2),
    (aliases: ['playstation 3', 'ps3'], id: -3),
    (aliases: ['playstation 4', 'ps4'], id: -4),
    (aliases: ['playstation vita', 'ps vita', 'psvita', 'vita'], id: -5),
    (aliases: ['xbox 360', 'xbox360'], id: -7),
    (aliases: ['xbox'], id: -6),
    (aliases: ['nintendo 3ds', '3ds'], id: 62),
    (aliases: ['famicom disk system', 'famicom disk', 'fds', 'disk system'], id: 81),
    (aliases: ['atari jaguar cd', 'jaguar cd', 'jaguarcd'], id: 77),
    (aliases: ['neo geo cd', 'neogeo cd', 'neogeocd'], id: 56),
    (aliases: ['sg-1000', 'sg1000'], id: 33),
    (aliases: ['colecovision', 'coleco'], id: 44),
    (aliases: ['intellivision', 'intv'], id: 45),
    (aliases: ['vectrex'], id: 46),
    (aliases: ['pc-fx', 'pcfx'], id: 49),
    (aliases: ['fairchild channel f', 'channel f', 'channelf', 'fairchild'], id: 57),
    (aliases: ['playstation portable', 'psp'], id: 41),
    (aliases: ['playstation 2', 'ps2'], id: 21),
    (aliases: ['playstation', 'ps1', 'psx', 'psone'], id: 12),
    (aliases: ['gamecube', 'game cube', 'ngc', 'gc'], id: 16),
    (aliases: ['nintendo wii', 'wii'], id: 19),
    (aliases: ['saturn'], id: 39),
    (aliases: ['dreamcast', 'dc'], id: 40),
    (aliases: ['mega cd', 'megacd', 'sega cd', 'segacd'], id: 9),
    (aliases: ['pc engine cd', 'pcecd', 'turbografx cd', 'turbografx-cd'], id: 76),
    (aliases: ['pc engine', 'pcengine', 'turbografx', 'tg16', 'tg-16', 'pce'], id: 8),
    (aliases: ['3do'], id: 43),
    (aliases: ['super nintendo', 'super famicom', 'snes', 'sfc'], id: 3),
    (aliases: ['nintendo 64', 'n64'], id: 2),
    (aliases: ['nintendo dsi', 'dsi'], id: 78),
    (aliases: ['nintendo ds', 'nds'], id: 18),
    (aliases: ['pokémon mini', 'pokemon mini', 'pokemonmini'], id: 24),
    (aliases: ['game boy advance', 'gameboy advance', 'gba'], id: 5),
    (aliases: ['game boy color', 'gameboy color', 'gbc'], id: 6),
    (aliases: ['game boy', 'gameboy', 'gb'], id: 4),
    (aliases: ['virtual boy', 'virtualboy', 'vb'], id: 28),
    (aliases: ['nes', 'famicom'], id: 7),
    (aliases: ['sega 32x', '32x'], id: 10),
    (aliases: ['mega drive', 'megadrive', 'genesis', 'md'], id: 1),
    (aliases: ['master system', 'mastersystem', 'sms'], id: 11),
    (aliases: ['game gear', 'gamegear', 'gg'], id: 15),
    (aliases: ['atari lynx', 'lynx'], id: 13),
    // Must come before generic 'arcade' / 'neogeo' entries below.
    (aliases: ['neo geo pocket', 'neogeo pocket', 'ngp', 'ngpc'], id: 14),
    (aliases: ['atari jaguar', 'jaguar'], id: 17),
    (aliases: ['atari 2600', '2600'], id: 25),
    (aliases: ['atari 7800', '7800'], id: 51),
    (aliases: ['wonderswan', 'wonder swan'], id: 53),
    // 'neogeo' (no space) can't match 'neo geo pocket', so the order is safe.
    (aliases: [
      'arcade', 'mame', 'fbneo', 'fb neo', 'fbalpha', 'fb',
      'naomi', 'atomiswave', 'neogeo', 'neo-geo',
    ], id: 27),
  ];

  /// Best-effort console id for a folder name, or null if unrecognized.
  static int? idForFolder(String folderName) {
    final name = p.basename(folderName).toLowerCase();
    for (final entry in _aliases) {
      for (final alias in entry.aliases) {
        if (name.contains(alias)) return entry.id;
      }
    }
    return null;
  }

  /// Manufacturer name for a console id, or 'Other' if unknown.
  static String manufacturerForId(int? consoleId) =>
      consoleId == null ? 'Other' : (_manufacturer[consoleId] ?? 'Other');

  /// Sort key for a manufacturer (lower = earlier in sort). Unknown sorts last.
  static int manufacturerSortKey(int? consoleId) {
    final idx = _manufacturerOrder.indexOf(manufacturerForId(consoleId));
    return idx == -1 ? _manufacturerOrder.length : idx;
  }
}
