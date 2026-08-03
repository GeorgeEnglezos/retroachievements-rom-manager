import '../models/rom_result.dart';

/// "Hot" = numPlayersCasual >= this. One constant so every surface agrees.
const int hotPlayerThreshold = 10000;

/// True when [rom] qualifies as hot (see [hotPlayerThreshold]).
bool isHotGame(RomResult rom) =>
    rom.status == RomStatus.supported &&
    (rom.numPlayersCasual ?? 0) >= hotPlayerThreshold;
