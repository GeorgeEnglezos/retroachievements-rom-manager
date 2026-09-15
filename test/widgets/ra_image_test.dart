import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/ra_image_cache.dart';
import 'package:rarm/widgets/ra_image.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  // The whole offline bug was RaImage falling back to DefaultCacheManager,
  // whose 200-object cap evicts all but the newest 200 images. Every RA image
  // must go through the shared, large-cap manager instead.
  testWidgets('routes through the shared RA cache manager', (tester) async {
    await tester.pumpWidget(host(
      const RaImage(url: 'https://example.com/x.png', width: 100, height: 100),
    ));
    final img =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(img.cacheManager, same(raCacheManager));
  });

  testWidgets('zoomable image opens a fullscreen viewer on tap', (tester) async {
    await tester.pumpWidget(host(
      const RaImage(
          url: 'https://example.com/x.png',
          width: 100,
          height: 100,
          zoomable: true),
    ));
    await tester.tap(find.byType(RaImage));
    await tester.pump(); // start the dialog route
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('non-zoomable image does not open a viewer on tap',
      (tester) async {
    await tester.pumpWidget(host(
      const RaImage(url: 'https://example.com/x.png', width: 100, height: 100),
    ));
    await tester.tap(find.byType(RaImage), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  test('raImageUrl builds a full URL from an RA path', () {
    expect(raImageUrl('/Images/1.png'),
        'https://retroachievements.org/Images/1.png');
  });

  test('raImageUrl passes an absolute third-party url through unchanged', () {
    expect(raImageUrl('https://cdn.screenscraper.fr/box.png'),
        'https://cdn.screenscraper.fr/box.png');
  });

  group('raAvatarUrl', () {
    // The media host is case-sensitive: a lowercase path can serve a stale
    // legacy image. So the canonical UserPic path must pass through verbatim,
    // never be rebuilt from a (possibly lowercased) username.
    test('uses the UserPic path verbatim, preserving case', () {
      expect(
        raAvatarUrl('/UserPic/Geonek.png'),
        'https://media.retroachievements.org/UserPic/Geonek.png',
      );
    });

    test('appends a version query to cache-bust a changed avatar', () {
      expect(
        raAvatarUrl('/UserPic/Geonek.png', version: 42),
        'https://media.retroachievements.org/UserPic/Geonek.png?v=42',
      );
    });
  });
}
