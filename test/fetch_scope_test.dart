import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/fetch_scope.dart';
import 'package:rarm/models/fetch_plan.dart';

void main() {
  const all = ['/a', '/b', '/c'];
  const changed = ['/b'];
  const unfetched = {'/c'}; // gamesScanned == 0

  test('all returns every folder', () {
    expect(
        resolveScopeFolders(
            scope: FetchScope.all,
            allFolders: all,
            changedFolders: changed,
            unfetchedFolders: unfetched),
        all);
  });

  test('changedFolders returns only changed', () {
    expect(
        resolveScopeFolders(
            scope: FetchScope.changedFolders,
            allFolders: all,
            changedFolders: changed,
            unfetchedFolders: unfetched),
        ['/b']);
  });

  test('unfetchedFolders returns folders with nothing fetched, in folder order',
      () {
    expect(
        resolveScopeFolders(
            scope: FetchScope.unfetchedFolders,
            allFolders: all,
            changedFolders: changed,
            unfetchedFolders: unfetched),
        ['/c']);
  });
}
