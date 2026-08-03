import 'package:path/path.dart' as p;

/// Canonical store/index key for a ROM path: normalized and lowercased so
/// lookups survive separator and case differences.
String romPathKey(String path) => p.normalize(path).toLowerCase();
