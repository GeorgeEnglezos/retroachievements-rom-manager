import 'package:path/path.dart' as p;

/// Nintendo Switch dumps ship a game as several files: the base game, each
/// update, and every DLC, all separate .nsp/.xci carrying their own 16-hex
/// title id. Only the base file boots; emulators load updates and DLC through
/// it. These helpers let a title's files collapse into one listing entry the
/// way a multi-disc set does (see [DiscGroup] in disc_grouping.dart).

/// A Switch file's role in its title, in display order.
enum SwitchPart { base, update, dlc }

const _switchExtensions = {'.nsp', '.xci', '.nca', '.nro', '.nso'};

/// Whether [fileName] is a Switch container. Grouping is gated on this so no
/// other console's filenames can be collapsed by accident.
bool isSwitchFile(String fileName) =>
    _switchExtensions.contains(p.extension(fileName).toLowerCase());

// The title id, e.g. [010025C0145D4000].
final _titleIdPattern = RegExp(r'\[([0-9a-fA-F]{16})\]');
// The update revision as Nintendo counts it, 65536 per release: [v196608].
final _versionPattern = RegExp(r'\[v(\d+)\]');
// The human version some dumpers print beside it: [1.12.0].
final _semverPattern = RegExp(r'\[(\d+\.\d+(?:\.\d+)?)\]');
// Every bracketed block; none of them belong in a displayed title.
final _bracketPattern = RegExp(r'\[[^\]]*\]');

/// The 16-hex title id in [fileName], uppercased, or null if it carries none.
String? switchTitleId(String fileName) => !isSwitchFile(fileName)
    ? null
    : _titleIdPattern.firstMatch(fileName)?.group(1)!.toUpperCase();

/// What [fileName] is within its title, read from the title id's low 3 hex
/// digits: a base id ends in `000`, its update is that id + `800`, and each
/// DLC is the id + `1000` plus an index. Files with no title id fall back to
/// the `[Update]` / `[UPD]` / `DLC` markers dumpers add, and default to
/// [SwitchPart.base] (a plain `Game.nsp` is the game).
SwitchPart switchPart(String fileName) {
  final id = switchTitleId(fileName);
  if (id != null) {
    final low = int.parse(id.substring(12), radix: 16) & 0xFFF;
    if (low == 0x000) return SwitchPart.base;
    if (low == 0x800) return SwitchPart.update;
    return SwitchPart.dlc;
  }
  final lower = fileName.toLowerCase();
  if (lower.contains('[update]') || lower.contains('[upd]')) {
    return SwitchPart.update;
  }
  return lower.contains('dlc') ? SwitchPart.dlc : SwitchPart.base;
}

/// The update revision in [fileName], or null when it carries no `[v…]`.
int? switchVersion(String fileName) {
  final m = _versionPattern.firstMatch(fileName);
  return m == null ? null : int.parse(m.group(1)!);
}

/// Key collapsing a title's base, updates and DLC into one group: the title id
/// with its low 4 hex digits cleared, which is the only part that differs
/// between them. Null without a title id: a name-based fallback would also
/// collapse region variants of ordinary ROMs, which are separate games.
String? switchGroupKey(String fileName) {
  final id = switchTitleId(fileName);
  return id == null ? null : '${id.substring(0, 12)}0000';
}

/// Orders one title's files for display: base first (the bootable one), then
/// updates oldest to newest, then DLC.
int compareSwitchParts(String a, String b) {
  final byPart = switchPart(a).index.compareTo(switchPart(b).index);
  if (byPart != 0) return byPart;
  final byVersion = (switchVersion(a) ?? 0).compareTo(switchVersion(b) ?? 0);
  if (byVersion != 0) return byVersion;
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// [fileName] without its extension or any bracketed block, which is where the
/// title id, version and dumper tags all live.
String switchDisplayTitle(String fileName) =>
    p.basenameWithoutExtension(fileName)
        .replaceAll(_bracketPattern, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

/// Display labels for one title's [fileNames], index-aligned to the input.
/// DLC is numbered only when a title has more than one, so the common case
/// reads "DLC" rather than "DLC 1".
List<String> switchPartLabels(List<String> fileNames) {
  final numberDlc =
      fileNames.where((f) => switchPart(f) == SwitchPart.dlc).length > 1;
  var dlc = 0;
  return [
    for (final name in fileNames)
      switch (switchPart(name)) {
        SwitchPart.base => 'Base',
        SwitchPart.update => _updateLabel(name),
        SwitchPart.dlc => numberDlc ? 'DLC ${++dlc}' : 'DLC',
      },
  ];
}

String _updateLabel(String fileName) {
  final semver = _semverPattern.firstMatch(fileName)?.group(1);
  if (semver != null) return 'Update $semver';
  final v = switchVersion(fileName) ?? 0;
  return v == 0 ? 'Update' : 'Update v${v ~/ 65536}';
}
