/// One weighted entry in the Storage drill-down. [path] is the on-disk location
/// the entry represents, used to drill down a level; null for synthetic items.
class TreemapItem {
  final String label;
  final int bytes;
  final String? path;
  const TreemapItem(this.label, this.bytes, {this.path});
}
