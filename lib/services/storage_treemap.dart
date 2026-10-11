/// One weighted entry in the Storage drill-down. [path] is the on-disk location
/// the entry represents, used to drill down a level; null for synthetic items.
/// [isFile] is set while walking, so the UI never stats the path itself.
class TreemapItem {
  final String label;
  final int bytes;
  final String? path;
  final bool isFile;
  const TreemapItem(this.label, this.bytes, {this.path, this.isFile = false});
}
