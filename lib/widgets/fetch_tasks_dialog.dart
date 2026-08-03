import 'package:flutter/material.dart';

import '../models/fetch_plan.dart';

/// The unified fetch/scan modal; [global] adds RA-list refresh + scope.
/// Returns null on cancel.
Future<FetchPlan?> showFetchTasksDialog(
  BuildContext context, {
  required bool global,
}) {
  var scope = FetchScope.all;
  var match = true;
  var matchReFetchAll = false;
  var progress = false;

  final scanStep = global ? 3 : 2; // the "Fetch & match" step number

  String scopeLabel(FetchScope s) => switch (s) {
    FetchScope.changedFolders => 'Only changed folders',
    FetchScope.unfetchedFolders => 'Only unfetched folders',
    FetchScope.all => 'All folders',
  };

  return showDialog<FetchPlan>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);

      // A numbered step badge with a bold title and a one-line explanation.
      Widget stepHeader(String number, String title, String subtitle) =>
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    number,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

      return StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Fetch'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step 1: standalone disk re-walk. No RA calls; closes now.
                  stepHeader(
                    '1',
                    global ? 'Refresh folders & files' : 'Refresh files',
                    'Re-read disk for added/removed files. No RA calls.',
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(
                      ctx,
                      FetchPlan(scope: scope, refresh: true),
                    ),
                    icon: const Icon(Icons.folder_open),
                    label: Text(
                      global ? 'Refresh folders & files' : 'Refresh files',
                    ),
                  ),
                  if (global) ...[
                    const SizedBox(height: 14),
                    // Step 2: standalone RA list re-pull. Unrelated to the scan.
                    stepHeader(
                      '2',
                      'Refresh RA game lists',
                      'Re-pull each console\'s game/hash list from RA. '
                          'Unrelated to the scan below.',
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(
                        ctx,
                        FetchPlan(scope: scope, refreshLists: true),
                      ),
                      icon: const Icon(Icons.cloud_sync),
                      label: const Text('Refresh RA game lists'),
                    ),
                  ],
                  const Divider(height: 28),
                  // Final step: the scan; runs via the Run action button.
                  stepHeader(
                    '$scanStep',
                    'Fetch & match',
                    'Hash your ROMs and sync with RetroAchievements.',
                  ),
                  if (global) ...[
                    RadioGroup<FetchScope>(
                      groupValue: scope,
                      onChanged: (v) => setDlgState(() => scope = v!),
                      child: Column(
                        children: [
                          for (final s in FetchScope.values)
                            RadioListTile<FetchScope>(
                              title: Text(scopeLabel(s)),
                              value: s,
                              dense: true,
                            ),
                        ],
                      ),
                    ),
                  ],
                  CheckboxListTile(
                    title: const Text('Match with RA'),
                    subtitle: const Text(
                      'Hash ROMs and look up RetroAchievements',
                    ),
                    value: match,
                    onChanged: (v) => setDlgState(() => match = v ?? false),
                    dense: true,
                  ),
                  if (match)
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: RadioGroup<bool>(
                        groupValue: matchReFetchAll,
                        onChanged: (v) =>
                            setDlgState(() => matchReFetchAll = v!),
                        child: const Column(
                          children: [
                            RadioListTile<bool>(
                              title: Text('Only unfetched'),
                              value: false,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<bool>(
                              title: Text('Re-fetch all'),
                              value: true,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                  CheckboxListTile(
                    title: const Text('Fetch progress'),
                    subtitle: const Text('Sync achievement progress from RA'),
                    value: progress,
                    onChanged: (v) => setDlgState(() => progress = v ?? false),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (match || progress)
                  ? () => Navigator.pop(
                      ctx,
                      FetchPlan(
                        scope: scope,
                        match: match,
                        matchReFetchAll: matchReFetchAll,
                        progress: progress,
                      ),
                    )
                  : null,
              child: const Text('Run'),
            ),
          ],
        ),
      );
    },
  );
}
