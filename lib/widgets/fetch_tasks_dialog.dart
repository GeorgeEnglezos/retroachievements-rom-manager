import 'package:flutter/material.dart';

import '../models/fetch_plan.dart';
import '../services/ra_cache.dart';
import 'ui/ui_focusable.dart';
import '../strings.dart';

/// The fetch modal: one primary action, with the rare choices folded away.
///
/// Nothing routine is asked. Re-reading the folders off disk is local and
/// free; each console's RA game list re-pulls itself once it passes
/// [RaCache.listTtl]; and the progress sync is one account-wide sweep whatever
/// the library's size. None of those is a decision worth putting to the user,
/// so the button just does them. What survives under Advanced is the one
/// genuinely expensive choice (re-hashing ROMs already identified), the manual
/// override for the list cache, and, on the global run, which folders to touch
/// and whether to delete data for folders that are gone.
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
  var pruneMissing = false;

  String scopeLabel(FetchScope s) => switch (s) {
        FetchScope.changedFolders => FetchStrings.scopeChanged,
        FetchScope.unfetchedFolders => FetchStrings.scopeUnfetched,
        FetchScope.all => FetchStrings.scopeAll,
      };

  return showDialog<FetchPlan>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);

      return StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text(FetchStrings.dialogTitle),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    global
                        ? FetchStrings.globalDescription
                        : FetchStrings.folderDescription,
                    style: muted,
                  ),
                  // Collapsed by default: the whole point is that the button
                  // above needs no configuring.
                  Theme(
                    // The stock expansion dividers read as a section break the
                    // rest of this dialog doesn't have.
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text(FetchStrings.advanced),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (global) ...[
                          Text(FetchStrings.foldersLabel, style: muted),
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
                          UiFocusZoom(
                            child: CheckboxListTile(
                              title: const Text(FetchStrings.removeMissingTitle),
                              subtitle: const Text(FetchStrings.removeMissingSubtitle),
                              value: pruneMissing,
                              onChanged: (v) =>
                                  setDlgState(() => pruneMissing = v ?? false),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        UiFocusZoom(
                          child: CheckboxListTile(
                            title: const Text(FetchStrings.reHashTitle),
                            subtitle: const Text(FetchStrings.reHashSubtitle),
                            value: reHashAll,
                            onChanged: (v) =>
                                setDlgState(() => reHashAll = v ?? false),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        UiFocusZoom(
                          child: CheckboxListTile(
                            title: const Text(FetchStrings.refreshListsTitle),
                            subtitle: Text(
                              FetchStrings.refreshListsSubtitle(
                                  RaCache.listTtl.inDays),
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
                child: const Text(LibraryStrings.cancelButton),
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
                    pruneMissing: pruneMissing,
                  ),
                ),
                child: const Text(FetchStrings.updateButton),
              ),
            ),
          ],
        ),
      );
    },
  );
}
