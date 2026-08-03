import '../models/rom_result.dart';
import '../models/rom_tags.dart';
import 'member_key.dart';

enum ProgressState { notStarted, started, nearComplete, mastered }

/// Distinct genres present in [roms], sorted. Shared by the folder and
/// playlist views' filter panels.
List<String> availableGenres(List<RomResult> roms) {
  final set = <String>{
    for (final r in roms)
      if (r.genre != null && r.genre!.isNotEmpty) r.genre!,
  };
  return set.toList()..sort();
}

/// Filename-derived filter labels (regions + tag chips) present in [roms],
/// case-insensitively sorted.
List<String> availableTags(List<RomResult> roms) {
  final set = <String>{for (final r in roms) ...romFilterLabels(r.fileName)};
  return set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// The subset of [roms] passing [filter], resolving each rom's playlist
/// membership through [membership] (see [playlistMembership]).
List<RomResult> visibleRoms(List<RomResult> roms, RomFilter filter,
    Map<String, Set<String>> membership) {
  return roms.where((r) {
    final key = memberKeyFor(gameId: r.gameId, filePath: r.filePath);
    return filter.matches(r, playlistIdsForRom: membership[key] ?? const {});
  }).toList();
}

/// At or above this earned/total ratio (but not yet mastered) a game counts as
/// "near complete": the quickest mastery candidates.
const _nearCompleteRatio = 0.8;

/// A game counts as "recently played" if RA last-played is within this window.
const _recentlyPlayedWindow = Duration(days: 90);

/// Immutable description of the active ROM-list filter. All set criteria are
/// combined with AND; an all-default filter passes everything.
class RomFilter {
  final String text;
  final Set<String> genres;
  final Set<RomStatus> statuses;
  final bool onlyDuplicates;
  final Set<String> includePlaylistIds;
  final Set<String> excludePlaylistIds;
  final Set<ProgressState> progressStates;
  final bool onlyRecentlyPlayed;
  final bool onlyNoAchievements;

  // Filename-derived labels (regions + tag chips like Japan / ENG / HACK). A ROM
  // passes if it carries any selected label.
  final Set<String> tags;

  const RomFilter({
    this.text = '',
    this.genres = const {},
    this.statuses = const {},
    this.onlyDuplicates = false,
    this.includePlaylistIds = const {},
    this.excludePlaylistIds = const {},
    this.progressStates = const {},
    this.onlyRecentlyPlayed = false,
    this.onlyNoAchievements = false,
    this.tags = const {},
  });

  RomFilter copyWith({
    String? text,
    Set<String>? genres,
    Set<RomStatus>? statuses,
    bool? onlyDuplicates,
    Set<String>? includePlaylistIds,
    Set<String>? excludePlaylistIds,
    Set<ProgressState>? progressStates,
    bool? onlyRecentlyPlayed,
    bool? onlyNoAchievements,
    Set<String>? tags,
  }) =>
      RomFilter(
        text: text ?? this.text,
        genres: genres ?? this.genres,
        statuses: statuses ?? this.statuses,
        onlyDuplicates: onlyDuplicates ?? this.onlyDuplicates,
        includePlaylistIds: includePlaylistIds ?? this.includePlaylistIds,
        excludePlaylistIds: excludePlaylistIds ?? this.excludePlaylistIds,
        progressStates: progressStates ?? this.progressStates,
        onlyRecentlyPlayed: onlyRecentlyPlayed ?? this.onlyRecentlyPlayed,
        onlyNoAchievements: onlyNoAchievements ?? this.onlyNoAchievements,
        tags: tags ?? this.tags,
      );

  bool matches(RomResult rom, {required Set<String> playlistIdsForRom}) {
    if (text.isNotEmpty) {
      final needle = text.toLowerCase();
      final hay = '${rom.fileName} ${rom.gameTitle ?? ''}'.toLowerCase();
      if (!hay.contains(needle)) return false;
    }
    if (genres.isNotEmpty && !genres.contains(rom.genre)) return false;
    if (statuses.isNotEmpty && !statuses.contains(rom.status)) return false;
    if (onlyDuplicates && rom.duplicateGroupId == null) return false;
    for (final id in includePlaylistIds) {
      if (!playlistIdsForRom.contains(id)) return false;
    }
    for (final id in excludePlaylistIds) {
      if (playlistIdsForRom.contains(id)) return false;
    }
    if (progressStates.isNotEmpty) {
      final earned = rom.earnedAchievements;
      final total = rom.achievementCount;
      // Never fetched, progress never synced, or a matched game with no
      // achievement set: it is in no progress state at all, so it belongs in
      // none of the chips (letting it through listed unfetched games under
      // "Mastered").
      if (earned == null || total == null || total == 0) return false;
      final state = earned >= total
          ? ProgressState.mastered
          : earned == 0
              ? ProgressState.notStarted
              : earned / total >= _nearCompleteRatio
                  ? ProgressState.nearComplete
                  : ProgressState.started;
      if (!progressStates.contains(state)) return false;
    }
    if (onlyRecentlyPlayed) {
      final lp = rom.lastPlayed;
      if (lp == null ||
          DateTime.now().difference(lp) > _recentlyPlayedWindow) {
        return false;
      }
    }
    if (onlyNoAchievements &&
        !(rom.status == RomStatus.supported &&
            (rom.achievementCount ?? 0) == 0)) {
      return false;
    }
    if (tags.isNotEmpty &&
        romFilterLabels(rom.fileName).intersection(tags).isEmpty) {
      return false;
    }
    return true;
  }
}
