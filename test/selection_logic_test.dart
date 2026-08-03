import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/selection_logic.dart';

void main() {
  const paths = ['a.rom', 'b.rom', 'c.rom', 'd.rom', 'e.rom'];

  group('resolveSelection', () {
    test('ctrl-click unselected item adds it and sets anchor', () {
      final r = resolveSelection(
        current: {},
        sortedPaths: paths,
        tapped: 'c.rom',
        lastSelected: null,
        isShift: false,
      );
      expect(r.selected, {'c.rom'});
      expect(r.lastSelected, 'c.rom');
    });

    test('ctrl-click selected item removes it', () {
      final r = resolveSelection(
        current: {'c.rom'},
        sortedPaths: paths,
        tapped: 'c.rom',
        lastSelected: 'c.rom',
        isShift: false,
      );
      expect(r.selected, isEmpty);
      expect(r.lastSelected, 'c.rom');
    });

    test('shift-click selects range from anchor to tapped (forward)', () {
      final r = resolveSelection(
        current: {'b.rom'},
        sortedPaths: paths,
        tapped: 'd.rom',
        lastSelected: 'b.rom',
        isShift: true,
      );
      expect(r.selected, {'b.rom', 'c.rom', 'd.rom'});
      expect(r.lastSelected, 'b.rom'); // anchor must not change
    });

    test('shift-click selects range in reverse order', () {
      final r = resolveSelection(
        current: {'d.rom'},
        sortedPaths: paths,
        tapped: 'b.rom',
        lastSelected: 'd.rom',
        isShift: true,
      );
      expect(r.selected, {'b.rom', 'c.rom', 'd.rom'});
    });

    test('shift-click with no anchor falls back to toggle', () {
      final r = resolveSelection(
        current: {},
        sortedPaths: paths,
        tapped: 'c.rom',
        lastSelected: null,
        isShift: true,
      );
      expect(r.selected, {'c.rom'});
      expect(r.lastSelected, 'c.rom');
    });

    test('shift-click tapped path not in sorted list falls back to toggle', () {
      final r = resolveSelection(
        current: {},
        sortedPaths: paths,
        tapped: 'z.rom',
        lastSelected: 'b.rom',
        isShift: true,
      );
      expect(r.selected, {'z.rom'});
    });

    test('shift-click extends an existing multi-selection', () {
      final r = resolveSelection(
        current: {'b.rom', 'c.rom'},
        sortedPaths: paths,
        tapped: 'e.rom',
        lastSelected: 'b.rom',
        isShift: true,
      );
      expect(r.selected, {'b.rom', 'c.rom', 'd.rom', 'e.rom'});
    });
  });
}
