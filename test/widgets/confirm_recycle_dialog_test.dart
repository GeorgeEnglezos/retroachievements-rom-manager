import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/confirm_recycle_dialog.dart';

void main() {
  // Runs on the desktop test host, so it pins the non-Android (Recycle Bin)
  // wording. The Android hard-delete branch flips verb/suffix off the same
  // helper.
  test('desktop wording for single, multi-disc, and bulk deletes', () {
    // Guard: these assertions describe the desktop host only.
    expect(Platform.isAndroid, isFalse);

    expect(deleteConfirmMessage(name: 'Racer.md'),
        "Move 'Racer.md' to the Recycle Bin?");
    expect(deleteConfirmMessage(name: 'FF7', discs: 3),
        "Move all 3 discs of 'FF7' to the Recycle Bin?");
    expect(deleteConfirmMessage(files: 1), 'Move 1 file to the Recycle Bin?');
    expect(deleteConfirmMessage(files: 5), 'Move 5 files to the Recycle Bin?');
    expect(deletedConfirmation, 'Moved to Recycle Bin');
  });

  testWidgets('Delete resolves true, Cancel false', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await confirmRecycleDialog(context, 'Move 2 files?');
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text('Move 2 files?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(result, isTrue);
  });
}
