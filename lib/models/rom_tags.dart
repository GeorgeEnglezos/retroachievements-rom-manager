/// Parses `(...)`/`[...]` filename markers into tag chips. Pure and
/// Flutter-free; colours live in the widget layer.
enum RomTagKind {
  verified,
  hack,
  translated,
  homebrew,
  subset,
  bonus,
  prototype,
  beta,
  demo,
  badDump,
  overdump,
  checksum,
  fixed,
  pirate,
  trainer,
  badChecksum,
  alternate,
  sram,
  unlicensed,
  region,
  language,
}

class RomTag {
  final String label;
  final RomTagKind kind;
  const RomTag(this.label, this.kind);
}

// Detectors in display order; patterns only match inside markers so they
// can't trip over title words. Translations: see [_translationLang].
const _detectors = <(RomTagKind, String)>[
  (RomTagKind.verified, r'\[!\]'),
  (RomTagKind.hack, r'[\[(][^\])]*\bhack\b[^\])]*[\])]|\[h[0-9a-z]*\]'),
  (RomTagKind.subset, r'\[subset\b'),
  (RomTagKind.bonus, r'\[bonus\]'),
  (RomTagKind.homebrew, r'\(homebrew\)|~homebrew~|\(pd\)|jam build'),
  (RomTagKind.prototype, r'\(prototype\)|~prototype~'),
  (RomTagKind.beta, r'\(beta\)'),
  (RomTagKind.demo, r'\(demo\)'),
  (RomTagKind.badDump, r'\[b\d*\]'),
  (RomTagKind.overdump, r'\[o\d*\]'),
  (RomTagKind.checksum, r'\[c\d*\]'),
  (RomTagKind.fixed, r'\[f\d*\]'),
  (RomTagKind.pirate, r'\[p\d*\]'),
  (RomTagKind.trainer, r'\[t\d*\]'),
  (RomTagKind.badChecksum, r'\[x\d*\]'),
  (RomTagKind.alternate, r'\[a\d*\]'),
  (RomTagKind.sram, r'\(sram\)'),
  (RomTagKind.unlicensed, r'\(unl\)'),
];

const _labels = {
  RomTagKind.verified: 'GOOD',
  RomTagKind.hack: 'HACK',
  RomTagKind.homebrew: 'HOMEBREW',
  RomTagKind.subset: 'SUBSET',
  RomTagKind.bonus: 'BONUS',
  RomTagKind.prototype: 'PROTO',
  RomTagKind.beta: 'BETA',
  RomTagKind.demo: 'DEMO',
  RomTagKind.badDump: 'BAD DUMP',
  RomTagKind.overdump: 'OVERDUMP',
  RomTagKind.checksum: 'CHECKSUM',
  RomTagKind.fixed: 'FIXED',
  RomTagKind.pirate: 'PIRATE',
  RomTagKind.trainer: 'TRAINER',
  RomTagKind.badChecksum: 'BAD SUM',
  RomTagKind.alternate: 'ALT',
  RomTagKind.sram: 'SRAM',
  RomTagKind.unlicensed: 'UNL',
};

List<RomTag> romTags(String fileName) {
  final out = <RomTag>[];
  final lang = _translationLang(fileName);
  if (lang != null) out.add(RomTag(lang, RomTagKind.translated));
  out.addAll(_regionTags(fileName));
  out.addAll(_languageTags(fileName));
  for (final (kind, pattern) in _detectors) {
    if (RegExp(pattern, caseSensitive: false).hasMatch(fileName)) {
      out.add(RomTag(_labels[kind]!, kind));
    }
  }
  return out;
}

// Translation chips carry the target language ([T-Eng] -> ENG) so English
// can be coloured differently.
String? _translationLang(String fileName) {
  final m = RegExp(
    r'\[t[-+]([a-z]+)',
    caseSensitive: false,
  ).firstMatch(fileName);
  if (m != null) {
    final code = m.group(1)!.toUpperCase();
    return code.startsWith('EN') ? 'ENG' : code;
  }
  if (RegExp(r'\[en by|\(en\)', caseSensitive: false).hasMatch(fileName)) {
    return 'ENG';
  }
  return null;
}

// No-Intro full names (whole-token match) and GoodTools single-letter codes.
const _regionNames = {
  'usa': 'USA',
  'europe': 'Europe',
  'japan': 'Japan',
  'australia': 'Australia',
  'world': 'World',
  'korea': 'Korea',
  'china': 'China',
  'france': 'France',
  'germany': 'Germany',
  'italy': 'Italy',
  'spain': 'Spain',
  'brazil': 'Brazil',
  'canada': 'Canada',
};
const _regionCodes = {
  'U': 'USA',
  'E': 'Europe',
  'J': 'Japan',
  'A': 'Australia',
  'K': 'Korea',
  'C': 'China',
  'F': 'France',
  'G': 'Germany',
  'I': 'Italy',
  'S': 'Spain',
  'B': 'Brazil',
  'W': 'World',
};

const _regionChipLabels = {
  'USA': 'USA',
  'Europe': 'EUR',
  'Japan': 'JPN',
  'Australia': 'AUS',
  'World': 'WORLD',
  'Korea': 'KOR',
  'China': 'CHN',
  'France': 'FRA',
  'Germany': 'GER',
  'Italy': 'ITA',
  'Spain': 'SPA',
  'Brazil': 'BRA',
  'Canada': 'CAN',
};

const _languageCodes = {
  'en': 'ENG',
  'eng': 'ENG',
  'fr': 'FRE',
  'fre': 'FRE',
  'de': 'GER',
  'ger': 'GER',
  'es': 'SPA',
  'spa': 'SPA',
  'it': 'ITA',
  'ita': 'ITA',
  'ja': 'JPN',
  'jp': 'JPN',
  'jpn': 'JPN',
  'ko': 'KOR',
  'kor': 'KOR',
  'zh': 'CHI',
  'chi': 'CHI',
  'pt': 'POR',
  'por': 'POR',
  'nl': 'DUT',
  'dut': 'DUT',
  'sv': 'SWE',
  'swe': 'SWE',
  'pl': 'POL',
  'pol': 'POL',
  'ru': 'RUS',
  'rus': 'RUS',
};

/// Region(s) for [fileName], e.g. `(Japan)` -> {Japan}, `(UE)` -> {USA, Europe}.
Set<String> romRegions(String fileName) {
  final out = <String>{};
  for (final m in RegExp(r'\(([^)]*)\)').allMatches(fileName)) {
    for (final part in m.group(1)!.split(',')) {
      final name = _regionNames[part.trim().toLowerCase()];
      if (name != null) out.add(name);
    }
  }
  // GoodTools codes only when no full name found; the schemes don't mix.
  if (out.isEmpty) {
    for (final m in RegExp(r'\(([UEJAKCFGISBW]{1,4})\)').allMatches(fileName)) {
      for (final ch in m.group(1)!.split('')) {
        final r = _regionCodes[ch];
        if (r != null) out.add(r);
      }
    }
  }
  return out;
}

List<RomTag> _regionTags(String fileName) => [
  for (final region in romRegions(fileName))
    RomTag(
      _regionChipLabels[region] ?? region.toUpperCase(),
      RomTagKind.region,
    ),
];

List<RomTag> _languageTags(String fileName) {
  final out = <RomTag>[];
  for (final m in RegExp(r'\(([^)]*)\)').allMatches(fileName)) {
    final token = m.group(1)!;
    if (!token.contains(',')) continue;
    for (final part in token.split(',')) {
      final label = _languageCodes[part.trim().toLowerCase()];
      if (label != null && !out.any((tag) => tag.label == label)) {
        out.add(RomTag(label, RomTagKind.language));
      }
    }
  }
  return out;
}

/// All filterable labels for a file: region(s) + tag chips.
Set<String> romFilterLabels(String fileName) => {
  ...romRegions(fileName),
  ...romTags(
    fileName,
  ).where((tag) => tag.kind != RomTagKind.region).map((tag) => tag.label),
};
