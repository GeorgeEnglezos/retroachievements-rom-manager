/// Sort criteria for the home grid: folder cards and, when "Combine systems"
/// is on, console groups. Size and file count order largest-first; name and
/// system order A-Z, with name as the tiebreak within a manufacturer.
enum HomeSort { alphabetical, size, fileCount, system }

/// Dropdown label for each sort.
String homeSortLabel(HomeSort s) => switch (s) {
      HomeSort.alphabetical => 'Name',
      HomeSort.size => 'Size',
      HomeSort.fileCount => 'Files',
      HomeSort.system => 'System',
    };
