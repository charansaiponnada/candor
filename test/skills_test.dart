import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:candor/services/skills.dart';

Future<String?> runDetect(SkillEngine e, String q) async {
  final a = e.detect(q);
  if (a == null) return null;
  return e.run(a);
}

File makeNotesFile() =>
    File('${Directory.systemTemp.createTempSync('candor_notes').path}/notes.json');

SkillEngine engine({File? notesFile}) => SkillEngine(
    notesFile: notesFile == null ? null : () async => notesFile);

Future<String?> run(String q) async => runDetect(engine(), q);

void main() {
  group('arithmetic', () {
    test('basic precedence and unary minus', () async {
      expect(await run('2 + 3 * 4'), '2 + 3 * 4 = 14');
      expect(await run('-5 + 12'), '-5 + 12 = 7');
      expect(await run('10 / 4'), '10 / 4 = 2.5');
      expect(await run('2 ^ 10'), '2 ^ 10 = 1024');
    });

    test('does not hijack plain numbers or words', () async {
      expect(await run('12'), isNull);
      expect(await run('hello world'), isNull);
      expect(await run('what is 2 + 2'), '2 + 2 = 4');
    });

    test('rejects malformed input honestly, not silently', () async {
      expect(await run('2 +'), "I couldn't parse that expression.");
      expect(await run('3 ** 3'), "I couldn't parse that expression.");
      expect(await run('2 + (3'), "I couldn't parse that expression.");
    });

    test('accepts a leading sign', () async {
      expect(await run('+ 2'), '+ 2 = 2');
    });

    test('huge results use exponent notation', () async {
      expect(await run('10 ^ 21'), '10 ^ 21 = 1e21');
    });

    test('square roots route to the skill, not the model', () async {
      expect(await run('what is the square root of 144'), 'sqrt(144) = 12');
      expect(await run('square root of 9'), 'sqrt(9) = 3');
      expect(await run('sqrt 2'), 'sqrt(2) = 1.41421356237');
    });
  });

  group('converter', () {
test('length, weight, temperature', () async {
      expect(await run('convert 5 miles to km'), '5 miles = 8.04672 km');
      expect(await run('what is 100 cm in inches'), '100 cm = 39.3700787402 inches');
      expect(await run('100 C to F'), '100 °C = 212 °F');
    });

    test('rejects unknown units', () async {
      expect(await run('convert 5 blargh to km'), isNull);
    });
  });

  group('date/time', () {
    test('current time and date answer', () async {
      expect(await run('what is the current time',
        ), matches(RegExp(r"^It's \d{1,2}:\d{2}")));
      expect(await run("today's date"), contains(DateTime.now().year.toString()));
    });

    test('days until a named date', () async {
      expect(await run('how many days until christmas'),
          matches(RegExp(r'^\d+ days until christmas\.')));
    });
  });

  group('notes', () {
    test('save, then read back, then round-trip to disk', () async {
      final f = makeNotesFile();
      final e = engine(notesFile: f);
      expect(await runDetect(e, 'remember that milk expires Friday'),
          contains('milk expires Friday'));
      expect(await runDetect(e, 'what did i ask you to remember'),
          contains('milk expires Friday'));
      final raw =
          jsonDecode(await f.readAsString()) as List<Object?>;
      expect(raw.single.toString(), 'milk expires Friday');
    });

    test('nothing saved -> honest "no notes" answer', () async {
      expect(await runDetect(engine(notesFile: makeNotesFile()), 'show my notes'),
          contains('anything yet'));
    });
  });

  group('text tools', () {
    test('uppercase, reverse, word count', () async {
      expect(await run('shout hello world'), 'HELLO WORLD');
      expect(await run('reverse the text abc def'), 'fed cba');
      expect(await run('count the words in a b c d'), '4 words');
    });
  });

  test('platform tools stay routed ahead of skills', () async {
    expect(await run('set a timer for 5 minutes'), isNull);
  });
}