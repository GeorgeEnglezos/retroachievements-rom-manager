import 'package:flutter/material.dart';
import '../models/rom_tags.dart';
import 'ui/ui_badge.dart';

class RomTagBadge extends StatelessWidget {
  final RomTag tag;

  const RomTagBadge({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return UiBadge(label: tag.label, color: romTagColor(tag));
  }
}

Color romTagColor(RomTag tag) => switch (tag.kind) {
  RomTagKind.verified => const Color(0xFF16A34A),
  RomTagKind.translated =>
    tag.label == 'ENG' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
  RomTagKind.hack => const Color(0xFF7C3AED),
  RomTagKind.homebrew => const Color(0xFF0D9488),
  RomTagKind.subset => const Color(0xFF2563EB),
  RomTagKind.bonus => const Color(0xFFCA8A04),
  RomTagKind.prototype => const Color(0xFFEA580C),
  RomTagKind.beta => const Color(0xFFDB2777),
  RomTagKind.demo => const Color(0xFF0EA5E9),
  RomTagKind.badDump => const Color(0xFF78716C),
  RomTagKind.overdump => const Color(0xFF78716C),
  RomTagKind.checksum => const Color(0xFF7C3AED),
  RomTagKind.fixed => const Color(0xFF7C3AED),
  RomTagKind.pirate => const Color(0xFF7C3AED),
  RomTagKind.trainer => const Color(0xFF7C3AED),
  RomTagKind.badChecksum => const Color(0xFF7C3AED),
  RomTagKind.alternate => const Color(0xFFEA580C),
  RomTagKind.sram => const Color(0xFF65A30D),
  RomTagKind.unlicensed => const Color(0xFF64748B),
  RomTagKind.region => const Color(0xFF2563EB),
  RomTagKind.language => const Color(0xFF0EA5E9),
};
