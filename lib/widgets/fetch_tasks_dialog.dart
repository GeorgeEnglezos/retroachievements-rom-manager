import 'package:flutter/material.dart';

import '../models/fetch_plan.dart';
import '../services/ra_cache.dart';
import 'ui/ui_focusable.dart';

/// The fetch modal: one primary action, with the rare choices folded away.
///
/// Nothing routine is asked. Re-reading the folders off disk is local and
/// free; each console's RA game list re-pulls itself once it passes
/// [RaCache.listTtl]; and the progress sync is one account-wide sweep whatever
/// the library's size. None of those is a decision worth putting to the user,
/// so the button just does them. What survives under Advanced is the one
/// genuinely expensive choice (re-hashing ROMs already identified), the manual
/// override for the list cache, and, on the global run, which folders to touch.
///
/// [global] adds the folder scope; the per-folder view has only its own.
/// Returns null on cancel.
Future<FetchPlan?> showFetchTasksDialog(
  BuildContext context, {
  required bool global,
}) {
  var scope = FetchScope.all;
  var reHashAll = false;
  var refreshLists = false;

  String scopeLabel(FetchScope s) => switch (s) {
        FetchScope.changedFolders => 'Only changed folders',
        FetchScope.unfetchedFolders => 'Only unfetched folders',
        FetchScope.all => 'All folders',
      };

  return showDialog<FetchPlan>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);

      return StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Update library'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    global
                        ? 'Re-reads your folders for added and removed files, '
                            'hashes anything new, matches it on '
                            'RetroAchievements and syncs your progress.'
                        : 'Re-reads this folder for added and removed files, '
                            'hashes anything new, matches it on '
                            'RetroAchievements and syncs your progress.',
                    style: muted,
                  ),
                  // Collapsed by default: the whole point is that the button
                  // above needs no configuring.
                  Theme(
                    // The stock expansion dividers read as a section break the
                    // rest of this dialog doesn't have.
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text('Advanced'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (global) ...[
                          Text('Folders', style: muted),
                          RadioGroup<FetchScope>(
                            groupValue: scope,
                            onChanged: (v) => setDlgState(() => scope = v!),
                            child: Column(
                              children: [
                                for (final s in FetchScope.values)
                                  UiFocusZoom(
                                    child: RadioListTile<FetchScope>(
                                      title: Text(scopeLabel(s)),
                                      value: s,
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        UiFocusZoom(
                          child: CheckboxListTile(
                            title: const Text('Re-hash every ROM'),
                            subtitle: const Text(
                              'Slow: reads every file again, including ones '
                              'already identified.',
                            ),
                            value: reHashAll,
                            onChanged: (v) =>
                                setDlgState(() => reHashAll = v ?? false),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        UiFocusZoom(
                          child: CheckboxListTile(
                            title: const Text('Force refresh RA game lists'),
                            subtitle: Text(
                              'Normally re-pulled on their own every '
                              '${RaCache.listTtl.inDays} days.',
                            ),
                            value: refreshLists,
                            onChanged: (v) =>
                                setDlgState(() => refreshLists = v ?? false),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            UiFocusZoom(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ),
            UiFocusZoom(
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  FetchPlan(
                    scope: scope,
                    refresh: true,
                    refreshLists: refreshLists,
                    match: true,
                    matchReFetchAll: reHashAll,
                    progress: true,
                  ),
                ),
                child: const Text('Update'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
