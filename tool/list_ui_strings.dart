// Finds user-visible string literals written outside the catalog
// (lib/strings.dart). test/tool/list_ui_strings_test.dart fails on any it
// finds in lib/screens or lib/widgets, so new copy lands in the catalog.
//
// Run: dart run tool/list_ui_strings.dart [dir ...]   (default lib/screens lib/widgets)

import 'dart:io';

final _skipBefore = RegExp(r'(Key\(|^\s*(import|export|part))\s*$');

/// (line, text) of each string literal in [source] that looks like UI text.
/// Adjacent literals ('a ' 'b') are joined; interpolations are kept verbatim.
// ponytail: a lowercase one-word label ('ok') is skipped by the heuristic.
List<(int, String)> uiStrings(String source) {
  final out = <(int, String)>[];
  (int, int, String)? cur; // start, end, text of the literal being joined
  void flush() {
    if (cur == null) return;
    final (start, _, text) = cur!;
    final lineStart = source.lastIndexOf('\n', start - 1) + 1;
    final stmtStart = source.lastIndexOf(RegExp(r'[;{}]'), start - 1) + 1;
    if (!_skipBefore.hasMatch(source.substring(lineStart, start)) &&
        !source.substring(stmtStart, start).contains('LogService.') &&
        _looksLikeUiText(text)) {
      out.add(('\n'.allMatches(source.substring(0, start)).length + 1, text));
    }
    cur = null;
  }

  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      i = source.indexOf('\n', i);
      if (i < 0) break;
    } else if (source.startsWith('/*', i)) {
      i = source.indexOf('*/', i) + 2;
      if (i < 2) break;
    } else if (_isQuoteAt(source, i)) {
      final start = i;
      final (end, text) = _readString(source, i);
      final c = cur;
      if (c != null && source.substring(c.$2, start).trim().isEmpty) {
        cur = (c.$1, end, c.$3 + text);
      } else {
        flush();
        cur = (start, end, text);
      }
      i = end;
    } else {
      if (source[i].trim().isNotEmpty) flush();
      i++;
    }
  }
  flush();
  return out;
}

// A quote, or r' / r" that is not the tail of an identifier.
bool _isQuoteAt(String s, int i) =>
    s[i] == "'" ||
    s[i] == '"' ||
    (s[i] == 'r' &&
        i + 1 < s.length &&
        (s[i + 1] == "'" || s[i + 1] == '"') &&
        (i == 0 || !RegExp(r'\w').hasMatch(s[i - 1])));

/// Reads the literal starting at [i]; returns (index after it, its text).
(int, String) _readString(String s, int i) {
  final raw = s[i] == 'r';
  if (raw) i++;
  final q = s.startsWith(s[i] * 3, i) ? s[i] * 3 : s[i];
  final start = i + q.length;
  var j = start;
  while (j < s.length && !s.startsWith(q, j)) {
    if (!raw && s[j] == r'\') {
      j += 2;
    } else if (!raw && s.startsWith(r'${', j)) {
      j = _skipInterpolation(s, j + 2);
    } else {
      j++;
    }
  }
  final text = s
      .substring(start, j)
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"')
      .replaceAll(RegExp(r'\s*\n\s*'), ' ');
  return (j + q.length, text);
}

// Skips an interpolation body up to its closing brace, stepping over nested
// strings and braces. Returns the index after the '}'.
int _skipInterpolation(String s, int j) {
  var depth = 0;
  while (j < s.length) {
    if (_isQuoteAt(s, j)) {
      j = _readString(s, j).$1;
      continue;
    }
    if (s[j] == '{') depth++;
    if (s[j] == '}' && depth-- == 0) return j + 1;
    j++;
  }
  return j;
}

// Prose (has a space) or a capitalised label. Skips pref keys, paths, ids.
bool _looksLikeUiText(String s) =>
    s.contains(RegExp('[A-Za-z]')) &&
    !s.contains('/') &&
    (s.contains(' ') || RegExp('^[A-Z]').hasMatch(s));

/// file:line: text for every UI-looking literal in [paths] (files or dirs).
List<String> strayUiStrings(List<String> paths) => [
      for (final path in paths)
        for (final f in path.endsWith('.dart')
            ? [File(path)]
            : Directory(path)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart')))
          for (final (line, text) in uiStrings(f.readAsStringSync()))
            '${f.path.replaceAll(r'\', '/')}:$line: $text',
    ];

void main(List<String> args) {
  final hits =
      strayUiStrings(args.isEmpty ? ['lib/screens', 'lib/widgets'] : args);
  hits.forEach(stdout.writeln);
  stdout.writeln('${hits.length} strings outside lib/strings.dart');
}
