/// On-device skills (Gallery-style "skills" made deterministic and offline):
/// calculator, unit converter, date/time, quick notes, text helpers. Same
/// trigger-then-execute flow as the intent tools in tools.dart — regex detect,
/// pure Dart run, no model pass, no network.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';

/// Single source of truth for tool/skill icons (chat cards + hub tiles).
IconData toolIcon(ToolKind kind) => switch (kind) {
      ToolKind.launchApp => Icons.open_in_new_rounded,
      ToolKind.setTimer => Icons.timer_rounded,
      ToolKind.sms => Icons.sms_rounded,
      ToolKind.email => Icons.mail_rounded,
      ToolKind.website => Icons.public_rounded,
      ToolKind.deviceControl => Icons.tune_rounded,
      ToolKind.calculate => Icons.calculate_rounded,
      ToolKind.converter => Icons.swap_horiz_rounded,
      ToolKind.dateTime => Icons.event_rounded,
      ToolKind.note => Icons.sticky_note_2_rounded,
      ToolKind.textTool => Icons.text_fields_rounded,
      ToolKind.random => Icons.casino_rounded,
    };

/// A skill's hub-screen card and its example prompts.
class Skill {
  final ToolKind kind;
  final String name;
  final String description;
  final List<String> examples;
  const Skill(this.kind, this.name, this.description, this.examples);
}

/// The whole skill catalog, offline and deterministic. Shown on the Skills
/// hub; tapping an example sends it into the chat box.
const skillsCatalog = [
  Skill(ToolKind.launchApp, 'Open apps',
      'Launch an installed app — Camera, Maps, YouTube and more.',
      ['Open the camera', 'Open maps']),
  Skill(ToolKind.setTimer, 'Timers & alarms',
      'Set a timer or alarm without touching anything.',
      ['Set a timer for 10 minutes', 'Set an alarm for 45 seconds']),
  Skill(ToolKind.sms, 'SMS',
      'Draft a text message to someone in your contacts.',
      ['Text mom that I am running late']),
  Skill(ToolKind.website, 'Websites',
      'Jump straight to a site by name or address.',
      ['Open github.com', 'Visit flutter.dev/docs']),
  Skill(ToolKind.deviceControl, 'Device controls',
      'Open system settings — wifi, bluetooth, display and more.',
      ['Open wifi settings', 'Open bluetooth settings']),
  Skill(ToolKind.email, 'Email',
      'Draft an email, with or without a recipient.',
      ['Email the team about the demo']),
  Skill(ToolKind.calculate, 'Calculator',
      'Arithmetic with + - * / ^ % and parentheses.',
      ['What is 128 * 4?', 'What is 15 + 25 * 2?']),
  Skill(ToolKind.converter, 'Unit converter',
      'Length, weight, volume, speed, time and temperature.',
      ['Convert 5 km to miles', 'What is 98.6 F in C?', 'Convert 2 pounds to kg']),
  Skill(ToolKind.dateTime, 'Date & time',
      'Today, the time, and countdowns to dates and holidays.',
      ['What is today\'s date?', 'How many days until Christmas?']),
  Skill(ToolKind.note, 'Quick notes',
      'Remember something and pull it back up whenever.',
      ['Remember that my wifi password is sunwaves', 'What did I ask you to remember?']),
  Skill(ToolKind.textTool, 'Text helpers',
      'Uppercase, reverse or word-count a phrase.',
      ['Shout candor is great', 'Reverse the text hello', 'Count the words in this sentence']),
  Skill(ToolKind.dateTime, 'World clock',
      'The current time in any major city — fully offline.',
      ['What time is it in Tokyo?', 'Time in London now']),
  Skill(ToolKind.random, 'Chance',
      'Roll dice or flip a coin — real randomness, on-device.',
      ['Roll 2 dice', 'Flip a coin']),
];

/// A detected skill trigger and the data needed to run it.
class SkillAction {
  final ToolKind kind;
  final String label; // short user-facing command, e.g. "18 * 7"
  final String tag; // per-kind variant: 'upper' | 'reverse' | 'count'
  SkillAction(this.kind, this.label, {this.tag = ''});
}

/// Detect + execute skills. Pure Dart: math (shunting-yard, no `eval`),
/// unit tables, date math, a JSON notes file. Returns a display string — or a
/// short failure line the chat card shows verbatim.
class SkillEngine {
  SkillEngine({Future<File> Function()? notesFile, math.Random? rng})
      : _notesFile = notesFile ?? _defaultNotesFile,
        _rng = rng ?? math.Random();

  static Future<File> _defaultNotesFile() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/notes.json');

  final Future<File> Function() _notesFile;
  List<String>? _notes;

  static final _calcRe = RegExp(
      r"^(?:what\s+is\s+|what'?s\s+|calculate\s+|compute\s+)?"
      r'([0-9().+\-*/%^ ]+)\??$',
      caseSensitive: false);
  static final _calcOpRe = RegExp(r'[+\-*/%^]');
  static final _sqrtRe = RegExp(
      r"^(?:(?:what|what's|what is)\s+(?:the\s+)?)?square root of\s*\(?(\d+(?:\.\d+)?)\)?\s*\??$",
      caseSensitive: false);
  static final _sqrtShortRe =
      RegExp(r'^sqrt\s*\(?(\d+(?:\.\d+)?)\)?\s*\??$', caseSensitive: false);

  static final _convertRe = RegExp(
      r'^(?:convert\s+)?([0-9.]+)\s*([a-zA-Z°]+)\s+(?:to|in|into)\s+([a-zA-Z°]+)$',
      caseSensitive: false);
  static final _convertQRe = RegExp(
      r"^what(?:'?s)?\s+is\s+([0-9.]+)\s*([a-zA-Z°]+)\s+in\s+([a-zA-Z°]+)\??$",
      caseSensitive: false);

  static final _timeRe = RegExp(
      r"^(?:(?:what\s+is|what'?s)\s+)?(?:(?:the\s+)?(?:time|current\s+time)|time\s+now)\??$",
      caseSensitive: false);
  static final _dateRe = RegExp(
      r"^(?:(?:what\s+is|what'?s)\s+)?(?:today's\s+date|(?:the\s+)?date\s+today|day\s+is\s+it\s+today)\??$",
      caseSensitive: false);
  static final _untilRe = RegExp(
      r'^how\s+many\s+days\s+(?:until|till|before)\s+(.+?)\s*\??$',
      caseSensitive: false);

  static final _noteSaveRe = RegExp(r'^(?:remember|note)\s+(?:that\s+|this\s+)?(.+)$',
      caseSensitive: false);
  static final _noteReadRe = RegExp(
      r'^(?:what\s+did\s+i\s+ask\s+you\s+to\s+remember|'
      r'(?:show|what\s+are|list)\s+my\s+notes)\??$',
      caseSensitive: false);

  static final _upperRe = RegExp(r'^(?:shout|uppercase)\s+(.+)$', caseSensitive: false);
  static final _reverseRe =
      RegExp(r'^reverse\s+(?:the\s+)?(?:text|word|phrase)\s+(.+)$', caseSensitive: false);
  static final _countRe =
      RegExp(r'^count\s+(?:the\s+)?words?\s+in\s+(.+)$', caseSensitive: false);

  static final _tzRe = RegExp(
      r"^(?:(?:what\s+time\s+(?:is\s+it|iz)?\s+in|time\s+in|current\s+time\s+in|time\s+at)\s+)([a-z][a-z\s'.-]*?)\s*\??$",
      caseSensitive: false);
  static final _diceRe = RegExp(
      r'^(?:roll\s+)?(?:a\s+)?(?:(\d{1,3})\s*d(?:ice|ie)?|d(\d{1,3}))\s*\??$',
      caseSensitive: false);
  static final _coinRe = RegExp(r'^(?:flip|toss)\s+(?:a\s+)?(?:coin)?\s*\??$',
      caseSensitive: false);

  final math.Random _rng;

  SkillAction? detect(String query) {
    final q = query.trim();
    if (q.isEmpty) return null;

    final calc = _calcRe.firstMatch(q);
    if (calc != null) {
      final expr = (calc.group(1) ?? '').trim();
      if (expr.isNotEmpty && _calcOpRe.hasMatch(expr)) {
        return SkillAction(ToolKind.calculate, expr);
      }
    }

    final sqrt = _sqrtRe.firstMatch(q) ?? _sqrtShortRe.firstMatch(q);
    if (sqrt != null) {
      return SkillAction(ToolKind.calculate, sqrt.group(1)!, tag: 'sqrt');
    }

    for (final re in [_convertRe, _convertQRe]) {
      final c = re.firstMatch(q);
      if (c != null) {
        final from = c.group(2)!.toLowerCase();
        final to = c.group(3)!.toLowerCase();
        if (_resolveUnit(from) != null || _isTemp(from)) {
          if (_resolveUnit(to) != null || _isTemp(to)) {
            return SkillAction(
                ToolKind.converter, '${c.group(1)} $from $to');
          }
        }
      }
    }

    if (_timeRe.hasMatch(q)) return SkillAction(ToolKind.dateTime, 'current time');
    if (_dateRe.hasMatch(q)) return SkillAction(ToolKind.dateTime, 'today');

    final tz = _tzRe.firstMatch(q);
    if (tz != null) {
      final city = tz.group(1)!.trim().toLowerCase();
      if (_zones.containsKey(city)) {
        return SkillAction(ToolKind.dateTime, 'tz $city');
      }
    }

    final until = _untilRe.firstMatch(q);
    if (until != null && _parseDate(until.group(1)!.trim()) != null) {
      return SkillAction(ToolKind.dateTime, 'until ${until.group(1)!.trim()}');
    }

    if (_noteReadRe.hasMatch(q)) return SkillAction(ToolKind.note, '');
    final save = _noteSaveRe.firstMatch(q);
    if (save != null) {
      return SkillAction(ToolKind.note, save.group(1)!.trim());
    }

    final upper = _upperRe.firstMatch(q);
    if (upper != null) {
      return SkillAction(ToolKind.textTool, upper.group(1)!.trim(), tag: 'upper');
    }
    final reverse = _reverseRe.firstMatch(q);
    if (reverse != null) {
      return SkillAction(ToolKind.textTool, reverse.group(1)!.trim(), tag: 'reverse');
    }
    final count = _countRe.firstMatch(q);
    if (count != null) {
      final text = count.group(1)!.trim();
      if (text.isNotEmpty) {
        return SkillAction(ToolKind.textTool, text, tag: 'count');
      }
    }

    final dice = _diceRe.firstMatch(q);
    if (dice != null) {
      return SkillAction(
          ToolKind.random, 'dice ${dice.group(1) ?? dice.group(2) ?? '1'}');
    }
    if (_coinRe.hasMatch(q)) return SkillAction(ToolKind.random, 'coin');

    return null;
  }

  Future<String> run(SkillAction a) async {
    switch (a.kind) {
      case ToolKind.calculate:
        if (a.tag == 'sqrt') {
          final n = double.parse(a.label);
          return 'sqrt(${fmtNumber(n)}) = ${fmtNumber(math.sqrt(n))}';
        }
        final v = evaluateArithmetic(a.label);
        return v == null ? "I couldn't parse that expression." : '${a.label} = ${fmtNumber(v)}';
      case ToolKind.converter:
        return _convert(a.label);
      case ToolKind.dateTime:
        return _dateTime(a.label);
      case ToolKind.random:
        if (a.label == 'coin') {
          return 'Coin flip: ${_rng.nextBool() ? 'heads' : 'tails'}.';
        }
        final count = int.tryParse(a.label.split(' ').last) ?? 1;
        final rolls = [for (var i = 0; i < count.clamp(1, 12); i++) _rng.nextInt(6) + 1];
        return rolls.length == 1
            ? 'You rolled a ${rolls.single}.'
            : 'You rolled ${rolls.join(' and ')} (total ${rolls.fold(0, (a2, b) => a2 + b)}).';
      case ToolKind.note:
        return a.label.isEmpty ? _readNotes() : _saveNote(a.label);
      case ToolKind.textTool:
        return switch (a.tag) {
          'upper' => a.label.toUpperCase(),
          'reverse' => reverseText(a.label),
          'count' => '${a.label.trim().split(RegExp(r'\s+')).length} words',
          _ => a.label,
        };
      default:
        return "I couldn't run that skill.";
    }
  }

  // ---- unit converter -------------------------------------------------

  static const Map<String, double> _length = {
    'mm': 0.001, 'cm': 0.01, 'm': 1.0, 'km': 1000.0,
    'in': 0.0254, 'inch': 0.0254, 'inches': 0.0254, '"': 0.0254,
    'ft': 0.3048, 'foot': 0.3048, 'feet': 0.3048, '\'': 0.3048,
    'yd': 0.9144, 'yard': 0.9144, 'yards': 0.9144,
    'mi': 1609.344, 'mile': 1609.344, 'miles': 1609.344,
    'nm': 1e-9, 'micrometer': 1e-6, 'um': 1e-6,
  };
  static const Map<String, double> _weight = {
    'mg': 0.001, 'g': 1.0, 'kg': 1000.0,
    't': 1e6, 'tonne': 1e6, 'tonnes': 1e6,
    'lb': 453.59237, 'lbs': 453.59237, 'pound': 453.59237, 'pounds': 453.59237,
    'oz': 28.349523125, 'ounce': 28.349523125, 'ounces': 28.349523125,
    'stone': 6350.29318, 'stones': 6350.29318,
  };
  static const Map<String, double> _volume = {
    'ml': 0.001, 'l': 1.0, 'liter': 1.0, 'liters': 1.0, 'litre': 1.0, 'litres': 1.0,
    'gal': 3.785411784, 'gallon': 3.785411784, 'gallons': 3.785411784,
    'qt': 0.946353, 'quart': 0.946353, 'quarts': 0.946353,
    'pt': 0.473176, 'pint': 0.473176, 'pints': 0.473176,
    'cup': 0.236588, 'cups': 0.236588,
  };
  static const Map<String, double> _speed = {
    'm/s': 1.0, 'km/h': 0.277778, 'kmh': 0.277778,
    'mph': 0.44704, 'knot': 0.514444, 'knots': 0.514444, 'kt': 0.514444,
  };
  static const Map<String, double> _time = {
    's': 1.0, 'sec': 1.0, 'secs': 1.0, 'second': 1.0, 'seconds': 1.0,
    'min': 60.0, 'mins': 60.0, 'minute': 60.0, 'minutes': 60.0,
    'h': 3600.0, 'hr': 3600.0, 'hrs': 3600.0, 'hour': 3600.0, 'hours': 3600.0,
    'day': 86400.0, 'days': 86400.0,
  };

  static const _temp = {'c': true, 'celsius': true, 'f': true, 'fahrenheit': true,
      'k': true, 'kelvin': true};

  static double? _resolveUnit(String unit) {
    for (final family in const [_length, _weight, _volume, _speed, _time]) {
      final f = family[unit];
      if (f != null) return f;
    }
    return null;
  }

  static bool _isTemp(String unit) => _temp.containsKey(unit);

  String _convert(String spec) {
    final parts = spec.split(' ');
    final v = double.tryParse(parts[0]);
    final from = parts[1].toLowerCase();
    final to = parts[2].toLowerCase();
    if (v == null) return "I couldn't read the number in that.";

    if (_isTemp(from) || _isTemp(to)) {
      if (!_isTemp(from) || !_isTemp(to)) return "I can't mix temperature with other units.";
      final c = _toCelsius(from, v);
      return '${fmtNumber(c)} °C = ${fmtNumber(_fromCelsius(to, c))} °${_tempAbbr(to)}';
    }

    final ff = _resolveUnit(from);
    final tf = _resolveUnit(to);
    if (ff == null || tf == null) return "I don't know one of those units.";
    final result = v * ff / tf;
    return '${fmtNumber(v)} $from = ${fmtNumber(result)} $to';
  }

  static double _toCelsius(String u, double v) => switch (u) {
        'f' || 'fahrenheit' => (v - 32) * 5 / 9,
        'k' || 'kelvin' => v - 273.15,
        _ => v,
      };

  static double _fromCelsius(String u, double v) => switch (u) {
        'f' || 'fahrenheit' => v * 9 / 5 + 32,
        'k' || 'kelvin' => v + 273.15,
        _ => v,
      };

  static String _tempAbbr(String u) => switch (u) {
        'f' || 'fahrenheit' => 'F',
        'k' || 'kelvin' => 'K',
        _ => 'C',
      };

  // ---- date & time ----------------------------------------------------

  // ---- world time (fixed offsets, no DST — honest, offline) ------------

  static const Map<String, double> _zones = {
    'london': 0, 'uk': 0, 'dublin': 0, 'lisbon': 0, 'reykjavik': 0,
    'madrid': 1, 'paris': 1, 'berlin': 1, 'rome': 1, 'amsterdam': 1,
    'lagos': 1, 'stockholm': 1, 'vienna': 1, 'brussels': 1, 'zurich': 1,
    'cairo': 2, 'athens': 3, 'istanbul': 3, 'moscow': 3, 'kiev': 3,
    'dubai': 4, 'tehran': 3.5, 'kabul': 4.5,
    'mumbai': 5.5, 'delhi': 5.5, 'new delhi': 5.5, 'calcutta': 5.5, 'karachi': 5,
    'dhaka': 6, 'dakar': 0, 'jakarta': 7, 'bangkok': 7, 'hanoi': 7,
    'singapore': 8, 'beijing': 8, 'hong kong': 8, 'manila': 8,
    'shanghai': 8, 'perth': 8, 'kuala lumpur': 8, 'taipei': 8,
    'tokyo': 9, 'seoul': 9, 'osaka': 9, 'sydney': 11, 'melbourne': 11,
    'auckland': 12, 'fiji': 12,
    'honolulu': -10, 'anchorage': -9,
    'los angeles': -8, 'san francisco': -8, 'seattle': -8, 'vancouver': -8,
    'denver': -7, 'salt lake city': -7,
    'chicago': -6, 'dallas': -6, 'houston': -6, 'mexico city': -6,
    'new york': -5, 'toronto': -5, 'miami': -5, 'boston': -5,
    'bogota': -5, 'lima': -5, 'quito': -5,
    'caracas': -4, 'santiago': -3, 'buenos aires': -3, 'sao paulo': -3,
    'rio de janeiro': -3, 'montevideo': -3,
  };

  String _dateTime(String spec) {
    if (spec.startsWith('tz ')) {
      final city = spec.substring(3).trim();
      final off = _zones[city]!;
      final local = DateTime.now().toUtc().add(
          Duration(milliseconds: (off * 3600 * 1000).round()));
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      final sign = off < 0 ? '-' : '+';
      final label = city.split(' ').map(_title).join(' ');
      return '≈ $hh:$mm in $label (UTC$sign${off.abs().toStringAsFixed(off == off.roundToDouble() ? 0 : 1)})';
    }
    final now = DateTime.now();
    if (spec == 'current time') {
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      return "It's $hh:$mm — ${_weekday(now.weekday)}.";
    }
    if (spec == 'today') {
      return "It's ${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}, ${now.year}.";
    }
    if (spec.startsWith('until ')) {
      final target = _parseDate(spec.substring(spec.indexOf(' ') + 1).trim());
      if (target == null) return "I couldn't parse that date.";
      final today = DateTime(now.year, now.month, now.day);
      final days = target.difference(today).inDays;
      final event = spec.substring(spec.indexOf(' ') + 1).trim();
      if (target == today) return 'That date is today.';
      if (days < 0) return 'That date has passed.';
      if (days == 1) return '1 day until $event.';
      return '$days days until $event.';
    }
    return "I couldn't answer that.";
  }

  static String _weekday(int w) => const {
        1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday',
        5: 'Friday', 6: 'Saturday', 7: 'Sunday',
      }[w]!;

  static String _month(int m) => const {
        1: 'January', 2: 'February', 3: 'March', 4: 'April', 5: 'May',
        6: 'June', 7: 'July', 8: 'August', 9: 'September', 10: 'October',
        11: 'November', 12: 'December',
      }[m]!;

  static final _monthNames = RegExp(
      'jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
      'jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?',
      caseSensitive: false);

  static final _events = <String, (int, int)>{
    'christmas': (12, 25), 'christmas day': (12, 25), 'xmas': (12, 25),
    'new year': (1, 1), "new year's": (1, 1), "new year's day": (1, 1),
    'new years': (1, 1), 'new years day': (1, 1),
    'halloween': (10, 31),
    "valentine's day": (2, 14), 'valentine': (2, 14),
    'thanksgiving': (11, 26), // US 2026; keep simple, model covers others
  };

  /// Parses "december 25", "dec 25", "25 december", ISO dates and named
  /// holidays. Returns the *next* occurrence for annual events (so "days
  /// until" is always forward-looking).
  static DateTime? _parseDate(String raw) {
    final s = raw.trim().toLowerCase();
    for (final e in _events.entries) {
      if (s == e.key) return _next(DateTime(DateTime.now().year, e.value.$1, e.value.$2));
    }
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (iso != null) {
      return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
          int.parse(iso.group(3)!));
    }
    final md = RegExp(r'^(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]+)$').firstMatch(s) ??
        RegExp(r'^([a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?$').firstMatch(s);
    if (md != null) {
      final month = _monthNumber(md.group(1)!);
      final day = int.parse(md.group(2)!);
      if (month != null && day >= 1 && day <= 31) {
        return _next(DateTime(DateTime.now().year, month, day));
      }
    }
    return null;
  }

  static int? _monthNumber(String s) {
    final mm = _monthNames.matchAsPrefix(s);
    if (mm == null) return null;
    return _monthMap[mm.group(0)!];
  }

  static const _monthMap = <String, int>{
    'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
    'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7,
    'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'sept': 9,
    'october': 10, 'oct': 10, 'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };

  /// Next occurrence of the given date (the one >= today), so "until" stays
  /// forward-looking even after the event has passed this year.
  static DateTime _next(DateTime d) {
    if (d.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
      return DateTime(d.year + 1, d.month, d.day);
    }
    return d;
  }

  // ---- notes -----------------------------------------------------------

  Future<List<String>> _loadNotes() async {
    if (_notes != null) return _notes!;
    try {
      final f = await _notesFile();
      if (await f.exists()) {
        _notes = (jsonDecode(await f.readAsString()) as List<Object?>).cast<String>();
      }
    } catch (_) {
      _notes = [];
    }
    return _notes ??= [];
  }

  Future<String> _saveNote(String note) async {
    final notes = await _loadNotes();
    notes.add(note);
    try {
      await (await _notesFile()).writeAsString(jsonEncode(notes));
    } catch (_) {
      return "I couldn't save that note.";
    }
    return 'Noted: $note';
  }

  Future<String> _readNotes() async {
    final notes = await _loadNotes();
    if (notes.isEmpty) return 'You haven\'t asked me to remember anything yet.';
    return notes.asMap().entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
  }
}

// ---- arithmetic (shunting-yard, no eval) ------------------------------

final RegExp _numRe = RegExp(r'^\d+(\.\d+)?$');
final RegExp _opRe = RegExp(r'^[+\-*/%^()]$');

final Map<String, (int, bool)> _prec = {
  'u-': (4, true), 'u+': (4, true),
  '^': (3, true), // right-assoc
  '*': (2, false), '/': (2, false), '%': (2, false),
  '+': (1, false), '-': (1, false),
};

bool _isNum(String t) => _numRe.hasMatch(t);

/// Evaluates basic arithmetic, or returns null for malformed input.
double? evaluateArithmetic(String expr) {
  final tokens = _tokenize(expr);
  if (tokens == null) return null;
  if (tokens.isEmpty) return null;

  final output = <String>[];
  final ops = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (_isNum(t)) {
      output.add(t);
      continue;
    }
    if (t == '(') {
      ops.add(t);
      continue;
    }
    if (t == ')') {
      while (ops.isNotEmpty && ops.last != '(') {
        output.add(ops.removeLast());
      }
      if (ops.isEmpty) return null; // unbalanced
      ops.removeLast();
      continue;
    }
    // operator (binary, or unary before a value / another operator / open paren)
    if (_opRe.hasMatch(t)) {
      final prev = i == 0 ? null : tokens[i - 1];
      final unary = (t == '-' || t == '+') &&
          (prev == null || _opRe.hasMatch(prev) || prev == '(');
      final op = unary ? 'u$t' : t;
      while (ops.isNotEmpty && !_isNum(ops.last) && ops.last != '(') {
        final topPrec = _prec[ops.last]!;
        final curPrec = _prec[op]!;
        if (topPrec.$1 > curPrec.$1 ||
            (topPrec.$1 == curPrec.$1 && !curPrec.$2)) {
          output.add(ops.removeLast());
        } else {
          break;
        }
      }
      ops.add(op);
      continue;
    }
    return null; // unknown token
  }
  while (ops.isNotEmpty) {
    if (ops.last == '(') return null; // unbalanced
    output.add(ops.removeLast());
  }

  final stack = <double>[];
  for (final t in output) {
    if (_isNum(t)) {
      stack.add(t.contains('.') ? double.parse(t) : double.parse(t).toDouble());
      continue;
    }
    final b = stack.isEmpty ? null : stack.removeLast();
    if (t == 'u-' || t == 'u+') {
      if (b == null) return null;
      stack.add(t == 'u-' ? -b : b);
      continue;
    }
    final a = stack.isEmpty ? null : stack.removeLast();
    if (a == null || b == null) return null;
    if (t == '+') stack.add(a + b);
    if (t == '-') stack.add(a - b);
    if (t == '*') stack.add(a * b);
    if (t == '%') {
      if (b == 0) return null;
      stack.add(a % b);
    }
    if (t == '/') {
      if (b == 0) return null;
      stack.add(a / b);
    }
    if (t == '^') stack.add(_pow(a, b));
  }
  if (stack.length != 1) return null;
  final v = stack.single;
  return v.isFinite ? v : null;
}

double _pow(double a, double b) {
  final r = math.pow(a, b).toDouble();
  return r.isFinite ? r : double.nan;
}

/// Splits an expression into number/operator tokens. Returns null on a token
/// it can't classify (a stray letter or bad character).
List<String>? _tokenize(String expr) {
  final out = <String>[];
  final buf = StringBuffer();
  for (var i = 0; i < expr.length; i++) {
    final c = expr[i];
    if (c == ' ') {
      if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
      continue;
    }
    if ('0123456789.'.contains(c)) {
      buf.write(c);
      continue;
    }
    if ('+-*/%^()'.contains(c)) {
      if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
      out.add(c);
      continue;
    }
    return null; // untokenable char
  }
  if (buf.isNotEmpty) out.add(buf.toString());
  return out;
}

String fmtNumber(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  var s = v.toStringAsPrecision(12).replaceFirst(RegExp(r'\.?0+$'), '');
  if (s.contains('e')) {
    // keep exponent notation readable: 1e21 plain
    final parts = s.split('e');
    s =
        '${parts[0].replaceFirst(RegExp(r'\.?0+$'), '')}e${int.tryParse(parts[1]) ?? parts[1]}';
  }
  return s;
}

String reverseText(String s) => String.fromCharCodes(s.runes.toList().reversed);

String _title(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');