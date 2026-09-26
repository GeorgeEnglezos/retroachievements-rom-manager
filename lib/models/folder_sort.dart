import '../strings.dart';

/// Sort criteria for the folder view ROM list. Duplicates is intentionally NOT
/// a sort option. The duplicate view is driven by RomFilter.onlyDuplicates and
/// rendered as MD5-grouped rows.
enum FolderSort {
  alphabetical,
  achievementCount,
  progress,
  lastPlayed,
  leastPlayed,
}

/// Human-readable dropdown label for each sort.
String folderSortLabel(FolderSort s) => switch (s) {
      FolderSort.alphabetical => SortStrings.name,
      FolderSort.achievementCount => SortStrings.achievements,
      FolderSort.progress => SortStrings.progress,
      FolderSort.lastPlayed => SortStrings.lastPlayed,
      FolderSort.leastPlayed => SortStrings.leastPlayed,
    };
