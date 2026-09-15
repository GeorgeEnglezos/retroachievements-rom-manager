import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/ra_image_cache.dart';
import 'image_viewer.dart';

/// Base host for RA artwork served under a leading-slash path (icons, box art,
/// screenshots). Badges live on media.retroachievements.org and are passed as
/// full URLs instead.
const raBaseUrl = 'https://retroachievements.org';

/// Builds a full artwork URL from an RA path like `/Images/1.png`. An absolute
/// url (a third-party provider's cover) passes through unchanged.
String raImageUrl(String path) =>
    path.startsWith('http') ? path : '$raBaseUrl$path';

/// Full avatar URL from RA's canonical UserPic path (`/UserPic/Name.png`, from
/// the profile API). The media host is case-sensitive, so this authoritative
/// path is the only reliable source; a URL built from a user-typed username can
/// serve a stale legacy image. The path is stable, so pass [version] to
/// cache-bust a changed avatar.
/// Bumped whenever the cached avatar prefs are rewritten, so a [FetchFab]
/// already on screen picks up a picture that resolved after it mounted.
final ValueNotifier<int> raAvatarListenable = ValueNotifier(0);

String raAvatarUrl(String userPicPath, {int? version}) =>
    'https://media.retroachievements.org$userPicPath'
    '${version == null ? '' : '?v=$version'}';

/// One RA image: disk-cached via [CachedNetworkImage], with an optional
/// tap-to-zoom fullscreen viewer. Every RA image in the app goes through this so
/// caching, placeholder, error fallback, and zoom behave identically.
class RaImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// When true, tapping opens a fullscreen pinch/drag viewer of the same image.
  final bool zoomable;

  /// Shown when the image fails to load. Defaults to a small placeholder box.
  final Widget? error;

  /// Shown while the image loads. Defaults to a sized transparent box.
  final Widget? placeholder;

  const RaImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.zoomable = false,
    this.error,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: url,
      cacheManager: raCacheManager,
      width: width,
      height: height,
      fit: fit,
      errorWidget: (_, _, _) => error ?? _defaultError(),
      placeholder: placeholder == null ? null : (_, _) => placeholder!,
    );
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    // Reserve the box while loading so layout (and the tap target) is stable
    // even before the image resolves.
    if (width != null || height != null) {
      image = SizedBox(width: width, height: height, child: image);
    }
    if (!zoomable) return image;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showImageViewer(
          context, CachedNetworkImageProvider(url, cacheManager: raCacheManager)),
      child: image,
    );
  }

  Widget _defaultError() => SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.broken_image_outlined),
      );
}
