import 'package:candor/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Phones report a status-bar inset: the bar must sit below it at full
  // toolbar height, and pushed screens need a visible way back.
  testWidgets('clears the status bar and adds Back on pushed screens',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildCandorTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(padding: const EdgeInsets.only(top: 40)),
          child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: const GlassAppBar(title: Text('Candor')),
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                    extendBodyBehindAppBar: true,
                    appBar: GlassAppBar(title: const Text('Settings'), actions: [
                      GlassIconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {},
                          size: 40),
                    ]),
                    body: const SizedBox.shrink()))),
            child: const Text('go'),
          ),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(GlassAppBar)).height, 56 + 40);
    expect(find.byTooltip('Back'), findsNothing); // the home route can't pop

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(tester.getTopLeft(find.byTooltip('Back')).dy,
        greaterThanOrEqualTo(40));

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
  });
}
