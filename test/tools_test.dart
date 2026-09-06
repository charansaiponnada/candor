import 'package:flutter_test/flutter_test.dart';
import 'package:candor/models.dart';
import 'package:candor/services/tools.dart';

void main() {
  const detector = ToolDetector();

  test('opens an app by name', () {
    final a = detector.detect('open the camera')!;
    expect(a.kind, ToolKind.launchApp);
    expect(a.label, 'Opened Camera');
    expect(a.packages, isNotEmpty);
  });

  test('set a timer for N minutes = N*60 seconds', () {
    final a = detector.detect('set a timer for 10 minutes')!;
    expect(a.kind, ToolKind.setTimer);
    expect(a.seconds, 600);
    expect(a.label, 'Timer set for 10 minutes');
  });

  test('set a timer for hours and seconds', () {
    expect(detector.detect('set timer for 2 hours')!.seconds, 7200);
    expect(detector.detect('start a timer for 45 sec')!.seconds, 45);
  });

  test('a duration alarm routes to the timer tool', () {
    final a = detector.detect('set a alarm for 15 secs')!;
    expect(a.kind, ToolKind.setTimer);
    expect(a.seconds, 15);
  });

  test('drafts an SMS with recipient and body', () {
    final a = detector.detect('text mom that I will be late')!;
    expect(a.kind, ToolKind.sms);
    expect(a.recipient, 'mom');
    expect(a.body, 'I will be late');
  });

  test('opens a website with or without a scheme', () {
    expect(detector.detect('open github.com')!.url, 'github.com');
    expect(
        detector.detect('visit https://flutter.dev/docs')!.url, 'flutter.dev/docs');
  });

  test('drafts an email', () {
    final a = detector.detect('email the team about the demo')!;
    expect(a.kind, ToolKind.email);
    expect(a.body, 'the demo');
  });

  test('ordinary questions are never routed to tools', () {
    expect(detector.detect('What is the square root of 144?'), isNull);
    expect(detector.detect('Explain recursion to a 12-year-old'), isNull);
    expect(detector.detect('What is the difference between LAN and WAN?'), isNull);
    expect(detector.detect('open source welcome packet'), isNull);
    expect(detector.detect(''), isNull);
  });
}