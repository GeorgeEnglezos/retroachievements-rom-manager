import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/update_check.dart';
import 'package:rarm/widgets/update_banner.dart';

void main() {
  Widget host(VoidCallback onDismiss, {double width = 1200}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: UpdateBanner(
              update: const ReleaseUpdate(
                  version: '1.2.0', url: 'https://example.test/release'),
              onDismiss: onDismiss,
            ),
          ),
        ),
      );

  testWidgets('shows the available version', (tester) async {
    await tester.pumpWidget(host(() {}));

    expect(find.text('v1.2.0'), findsOneWidget);
  });

  testWidgets('dismissing calls back', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(host(() => dismissed++));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(dismissed, 1);
  });

  testWidgets('lays out on a phone-width body without overflowing',
      (tester) async {
    // The shell renders this banner on mobile too, where the full wording plus
    // both controls does not fit; the label has to give way, not overflow.
    await tester.pumpWidget(host(() {}, width: 320));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('v1.2.0'), findsOneWidget); // version survives the squeeze
  });

  testWidgets('offers the link when no browser opens', (tester) async {
    // launchUrl reporting false is the desktop-with-no-http-handler case.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    String? copied;
    messenger.setMockMethodCallHandler(channel, (call) async => false);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(host(() {}));
    await tester.tap(find.text('GET IT'));
    await tester.pumpAndSettle();

    expect(copied, 'https://example.test/release');
    expect(find.textContaining('https://example.test/release'), findsWidgets);
  });
}
