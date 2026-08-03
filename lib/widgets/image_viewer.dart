import 'package:flutter/material.dart';

/// Fullscreen viewer for any image: pinch/drag to zoom, tap anywhere to dismiss.
/// Source-agnostic, so RA network art ([RaImage]) and imported local files
/// (Skraper) enlarge the same way; the caller supplies the provider.
void showImageViewer(BuildContext context, ImageProvider image) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: InteractiveViewer(
        child: Center(child: Image(image: image, fit: BoxFit.contain)),
      ),
    ),
  );
}
