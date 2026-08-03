/// True when a re-fetch shows the set grew (both counts known, new > old).
bool isSetUpdate(int? oldCount, int? newCount) =>
    oldCount != null && newCount != null && newCount > oldCount;
