import 'package:flutter_test/flutter_test.dart';

import '../../tool/list_ui_strings.dart';

// Literals the scanner flags that are never shown: log subjects handed to
// launchRomLogged and a tag comparison. Anything else belongs in lib/strings.dart.
const _notUi = {
  r'lib/widgets/app_shell.dart: shortcut ${pending.romPath}',
  r'lib/widgets/rom_actions.dart: ${rom.fileName} in ${emu.name}',
  r'lib/widgets/rom_actions.dart:  in $emulatorName',
  'lib/widgets/rom_tag_badge.dart: ENG',
};

void main() {
  test('uiStrings keeps visible text and skips code-only literals', () {
    const src = '''
import 'package:foo/foo.dart';
// A comment with 'Quoted Text'
Text('Fetch achievements'),
key: const ValueKey('top_title'),
prefs.getString('last_folder');
tooltip: "Don't stop",
Text('\$count game\${count == 1 ? '' : 's'} found'),
Text('Split across '
    'two lines'),
LogService.info('Tag', 'Scan finished');
''';
    expect(uiStrings(src), [
      (3, 'Fetch achievements'),
      (6, "Don't stop"),
      (7, r"$count game${count == 1 ? '' : 's'} found"),
      (8, 'Split across two lines'),
    ]);
  });

  test('no visible text is written outside lib/strings.dart', () {
    final stray = strayUiStrings(['lib/screens', 'lib/widgets'])
        .where((hit) =>
            !_notUi.contains(hit.replaceFirst(RegExp(r':\d+:'), ':')))
        .toList();
    expect(stray, isEmpty,
        reason: 'Move these into lib/strings.dart:\n${stray.join('\n')}');
  });
}
